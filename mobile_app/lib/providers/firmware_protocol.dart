import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

/// Enhanced binary protocol for ESP32 CC1101 BLE communication with chunking support
/// 
/// Protocol format (matching firmware):
/// [Magic:1][Type:1][ChunkID:1][ChunkNum:1][TotalChunks:1][DataLen:2][Data:variable][Checksum:1]
/// 
/// Where:
/// - Magic: 0xAA (packet identification)
/// - Type: 0x01=data, 0x02=ack, 0x03=nak
/// - ChunkID: Unique ID for chunk sequence (0-255)
/// - ChunkNum: Current chunk number (1-based)
/// - TotalChunks: Total number of chunks
/// - DataLen: Length of data in this packet (2 bytes, little-endian, max 500)
/// - Data: Actual data (max 500 bytes per packet for Bluetooth 5.0)
/// - Checksum: XOR checksum for error detection
/// 
/// Message Types:
/// 0x01 - getState
/// 0x02 - requestScan (minRssi:4, module:1)
/// 0x03 - requestIdle (module:1)
/// 0x05 - getFilesList (pathLength:1, path:variable)
/// 0x06 - transmitBinary (frequency:4, pulseDuration:1, data:variable)
/// 0x07 - transmitFromFile (pathLength:1, path:variable)
/// 0x08 - requestRecord (RequestRecord struct)
/// 0x09 - loadFileData (pathLength:1, path:variable)
/// 0x0A - createDirectory (pathLength:1, path:variable)
/// 0x0B - remove (pathLength:1, path:variable)
/// 0x0C - rename (fromLength:1, fromPath:variable, toLength:1, toPath:variable)
/// 0x0D - upload (file upload with chunking)
/// 0x12 - startJam (jamming command)
/// 0x14 - getDirectoryTree (pathType:1)
/// 
/// Special Message Types:
/// 0xFE - Chunk Data (for large responses)
/// 0xFF - Chunk Complete (indicates all chunks received)
class FirmwareBinaryProtocol {
  // Protocol constants (matching firmware)
  static const int MAGIC_BYTE = 0xAA;
  static const int PACKET_HEADER_SIZE = 7; // magic + type + chunk_id + chunk_num + total_chunks + data_len(2 bytes)
  static const int MAX_CHUNK_SIZE = 500; // Safe maximum: BLE notify limit is 509 bytes, so 509 - 7 (header) - 1 (checksum) - 1 (safety) = 500
  
  // Packet types (matching firmware)
  static const int PACKET_TYPE_DATA = 0x01;
  static const int PACKET_TYPE_ACK = 0x02;
  static const int PACKET_TYPE_NAK = 0x03;
  
  // Message types (for commands)
  static const int MSG_GET_STATE = 0x01;
  static const int MSG_REQUEST_SCAN = 0x02;
  static const int MSG_REQUEST_IDLE = 0x03;
  static const int MSG_GET_FILES_LIST = 0x05;
  static const int MSG_TRANSMIT_BINARY = 0x06;
  static const int MSG_TRANSMIT_FROM_FILE = 0x07;
  static const int MSG_REQUEST_RECORD = 0x08;
  static const int MSG_LOAD_FILE_DATA = 0x09;
  static const int MSG_CREATE_DIRECTORY = 0x0A;
  static const int MSG_REMOVE_FILE = 0x0B;
  static const int MSG_RENAME_FILE = 0x0C;
  static const int MSG_UPLOAD_FILE = 0x0D;
  static const int MSG_COPY_FILE = 0x0E;
  static const int MSG_MOVE_FILE = 0x0F;
  static const int MSG_SAVE_TO_SIGNALS_WITH_NAME = 0x10;
  static const int MSG_FREQUENCY_SEARCH = 0x11;
  static const int MSG_START_JAM = 0x12;
  static const int MSG_GET_DIRECTORY_TREE = 0x14; // Moved to 0x14 to avoid conflict
  static const int MSG_SET_TIME = 0x13;

  /// Calculate CRC32 checksum
  static int calculateCRC32(Uint8List data) {
    int crc = 0xFFFFFFFF;
    for (int byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc = crc >> 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// Convert int to network byte order (big-endian)
  static Uint8List intToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  /// Convert bytes to int from network byte order
  static int bytesToInt(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  /// Convert float to bytes
  static Uint8List floatToBytes(double value) {
    return Uint8List.fromList(value.toString().codeUnits);
  }

  /// Create getState command
  static Uint8List createGetStateCommand() {
    Uint8List payload = Uint8List(0);
    return _createEnhancedCommand(MSG_GET_STATE, payload);
  }

  /// Create requestScan command
  static Uint8List createRequestScanCommand(int minRssi, int module) {
    Uint8List payload = Uint8List(2);
    payload[0] = module;        // Module number (1 byte)
    payload[1] = minRssi;      // Min RSSI (1 byte, signed)
    return _createEnhancedCommand(MSG_REQUEST_SCAN, payload);
  }

  /// Create requestIdle command
  static Uint8List createRequestIdleCommand(int module) {
    Uint8List payload = Uint8List(1);
    payload[0] = module;
    return _createEnhancedCommand(MSG_REQUEST_IDLE, payload);
  }

  /// Create getFilesList command
  static Uint8List createGetFilesListCommand(String path, {int pathType = 0}) {
    List<int> pathBytes = utf8.encode(path);
    Uint8List payload = Uint8List(2 + pathBytes.length);
    payload[0] = pathBytes.length;
    payload[1] = pathType;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, etc.
    for (int i = 0; i < pathBytes.length; i++) {
      payload[2 + i] = pathBytes[i];
    }
    return _createEnhancedCommand(MSG_GET_FILES_LIST, payload);
  }

  /// Create getDirectoryTree command
  static Uint8List createGetDirectoryTreeCommand({int pathType = 0}) {
    Uint8List payload = Uint8List(1);
    payload[0] = pathType;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, etc.
    return _createEnhancedCommand(MSG_GET_DIRECTORY_TREE, payload);
  }

  /// Create transmitBinary command
  static Uint8List createTransmitBinaryCommand(double frequency, int pulseDuration, String data) {
    List<int> dataBytes = utf8.encode(data);
    Uint8List payload = Uint8List(5 + dataBytes.length);
    
    // Frequency as float (simplified - using 4 bytes)
    Uint8List freqBytes = floatToBytes(frequency);
    for (int i = 0; i < 4; i++) {
      payload[i] = freqBytes[i];
    }
    
    payload[4] = pulseDuration;
    for (int i = 0; i < dataBytes.length; i++) {
      payload[5 + i] = dataBytes[i];
    }
    
    return _createEnhancedCommand(MSG_TRANSMIT_BINARY, payload);
  }

  /// Create requestRecord command
  static Uint8List createRequestRecordCommand({
    required double frequency,
    required int module,
    String? preset,
    int? modulation,
    double? deviation,
    double? rxBandwidth,
    double? dataRate,
  }) {
    Uint8List payload = Uint8List(68); // RequestRecord struct size
    int offset = 0;
    
    // frequency (4 bytes)
    Uint8List freqBytes = _floatToBytes(frequency);
    for (int i = 0; i < 4; i++) {
      payload[offset + i] = freqBytes[i];
    }
    offset += 4;
    
    // preset (50 bytes) - null-terminated string
    List<int> presetBytes = utf8.encode(preset ?? '');
    int presetLen = presetBytes.length > 49 ? 49 : presetBytes.length;
    for (int i = 0; i < presetLen; i++) {
      payload[offset + i] = presetBytes[i];
    }
    // Fill remaining bytes with 0
    for (int i = presetLen; i < 50; i++) {
      payload[offset + i] = 0;
    }
    offset += 50;
    
    // module (1 byte)
    payload[offset] = module;
    offset += 1;
    
    // modulation (1 byte)
    payload[offset] = modulation ?? 0;
    offset += 1;
    
    // deviation (4 bytes)
    Uint8List devBytes = _floatToBytes(deviation ?? 0.0);
    for (int i = 0; i < 4; i++) {
      payload[offset + i] = devBytes[i];
    }
    offset += 4;
    
    // rxBandwidth (4 bytes)
    Uint8List bwBytes = _floatToBytes(rxBandwidth ?? 0.0);
    for (int i = 0; i < 4; i++) {
      payload[offset + i] = bwBytes[i];
    }
    offset += 4;
    
    // dataRate (4 bytes)
    Uint8List rateBytes = _floatToBytes(dataRate ?? 0.0);
    for (int i = 0; i < 4; i++) {
      payload[offset + i] = rateBytes[i];
    }
    
    return _createEnhancedCommand(MSG_REQUEST_RECORD, payload);
  }

  /// Helper function to convert float to bytes (little-endian)
  static Uint8List _floatToBytes(double value) {
    // Convert double to float (4 bytes) in little-endian format
    ByteData byteData = ByteData(4);
    byteData.setFloat32(0, value.toDouble(), Endian.little);
    return byteData.buffer.asUint8List();
  }

  /// Create transmitFromFile command with path type
  /// [module] - optional module number (-1 means auto-select first idle module)
  static Uint8List createTransmitFromFileCommand(String path, {int pathType = 0, int? module}) {
    List<int> pathBytes = utf8.encode(path);
    int payloadLength = 2 + pathBytes.length;
    if (module != null && module >= 0) {
      payloadLength += 1; // Add module byte if specified
    }
    Uint8List payload = Uint8List(payloadLength);
    payload[0] = pathBytes.length;
    payload[1] = pathType;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, etc.
    for (int i = 0; i < pathBytes.length; i++) {
      payload[2 + i] = pathBytes[i];
    }
    if (module != null && module >= 0) {
      payload[2 + pathBytes.length] = module;
    }
    return _createEnhancedCommand(MSG_TRANSMIT_FROM_FILE, payload);
  }

  /// Create loadFileData command
  /// Create loadFileData command with path type
  static Uint8List createLoadFileDataCommand(String path, {int pathType = 0}) {
    List<int> pathBytes = utf8.encode(path);
    Uint8List payload = Uint8List(2 + pathBytes.length);
    payload[0] = pathBytes.length;
    payload[1] = pathType;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, 2=/DATA/PRESETS, etc.
    for (int i = 0; i < pathBytes.length; i++) {
      payload[2 + i] = pathBytes[i];
    }
    return _createEnhancedCommand(MSG_LOAD_FILE_DATA, payload);
  }

  /// Create removeFile command with path type
  static Uint8List createRemoveFileCommand(String path, {int pathType = 0}) {
    List<int> pathBytes = utf8.encode(path);
    Uint8List payload = Uint8List(2 + pathBytes.length);
    payload[0] = pathBytes.length;
    payload[1] = pathType;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, etc.
    for (int i = 0; i < pathBytes.length; i++) {
      payload[2 + i] = pathBytes[i];
    }
    return _createEnhancedCommand(MSG_REMOVE_FILE, payload);
  }

  /// Create renameFile command with path type
  static Uint8List createRenameFileCommand(String fromPath, String toPath, {int pathType = 0}) {
    List<int> fromBytes = utf8.encode(fromPath);
    List<int> toBytes = utf8.encode(toPath);
    Uint8List payload = Uint8List(3 + fromBytes.length + toBytes.length);
    payload[0] = pathType;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, etc.
    payload[1] = fromBytes.length;
    for (int i = 0; i < fromBytes.length; i++) {
      payload[2 + i] = fromBytes[i];
    }
    payload[2 + fromBytes.length] = toBytes.length;
    for (int i = 0; i < toBytes.length; i++) {
      payload[3 + fromBytes.length + i] = toBytes[i];
    }
    return _createEnhancedCommand(MSG_RENAME_FILE, payload);
  }

  /// Create createDirectory command with path type
  static Uint8List createCreateDirectoryCommand(String path, {int pathType = 0}) {
    List<int> pathBytes = utf8.encode(path);
    Uint8List payload = Uint8List(2 + pathBytes.length);
    payload[0] = pathBytes.length;
    payload[1] = pathType;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, etc.
    for (int i = 0; i < pathBytes.length; i++) {
      payload[2 + i] = pathBytes[i];
    }
    return _createEnhancedCommand(MSG_CREATE_DIRECTORY, payload);
  }

  /// Create copyFile command with path type
  /// Format: [pathType:1][sourcePathLength:1][sourcePath:variable][destPathLength:1][destPath:variable]
  static Uint8List createCopyFileCommand(String sourcePath, String destPath, {int pathType = 0}) {
    List<int> sourceBytes = utf8.encode(sourcePath);
    List<int> destBytes = utf8.encode(destPath);
    Uint8List payload = Uint8List(3 + sourceBytes.length + destBytes.length);
    
    payload[0] = pathType;
    payload[1] = sourceBytes.length;
    for (int i = 0; i < sourceBytes.length; i++) {
      payload[2 + i] = sourceBytes[i];
    }
    payload[2 + sourceBytes.length] = destBytes.length;
    for (int i = 0; i < destBytes.length; i++) {
      payload[3 + sourceBytes.length + i] = destBytes[i];
    }
    
    return _createEnhancedCommand(MSG_COPY_FILE, payload);
  }

  /// Create moveFile command with separate path types for source and destination
  /// Format: [sourcePathType:1][destPathType:1][sourcePathLength:1][sourcePath:variable][destPathLength:1][destPath:variable]
  static Uint8List createMoveFileCommand(String sourcePath, String destPath, {int sourcePathType = 0, int destPathType = 0}) {
    List<int> sourceBytes = utf8.encode(sourcePath);
    List<int> destBytes = utf8.encode(destPath);
    Uint8List payload = Uint8List(4 + sourceBytes.length + destBytes.length);
    
    payload[0] = sourcePathType;
    payload[1] = destPathType;
    payload[2] = sourceBytes.length;
    for (int i = 0; i < sourceBytes.length; i++) {
      payload[3 + i] = sourceBytes[i];
    }
    payload[3 + sourceBytes.length] = destBytes.length;
    for (int i = 0; i < destBytes.length; i++) {
      payload[4 + sourceBytes.length + i] = destBytes[i];
    }
    
    return _createEnhancedCommand(MSG_MOVE_FILE, payload);
  }

  /// Create upload file command (first chunk with path)
  /// Format: [0x0D][pathLength:1][pathType:1][path:variable]
  static Uint8List createUploadFileStartCommand(String path, {int pathType = 0, int chunkId = 0, int totalChunks = 1}) {
    List<int> pathBytes = utf8.encode(path);
    Uint8List payload = Uint8List(3 + pathBytes.length);
    payload[0] = MSG_UPLOAD_FILE;  // Message type
    payload[1] = pathBytes.length; // Path length
    payload[2] = pathType;         // Path type
    for (int i = 0; i < pathBytes.length; i++) {
      payload[3 + i] = pathBytes[i];
    }
    return _createEnhancedCommandWithChunking(MSG_UPLOAD_FILE, chunkId, 1, totalChunks, payload);
  }

  /// Create upload file data chunk
  static Uint8List createUploadFileChunkCommand(Uint8List data, int chunkId, int chunkNum, int totalChunks) {
    return _createEnhancedCommandWithChunking(MSG_UPLOAD_FILE, chunkId, chunkNum, totalChunks, data);
  }

  /// Create enhanced command with chunking support
  static Uint8List _createEnhancedCommandWithChunking(int messageType, int chunkId, int chunkNum, int totalChunks, Uint8List payload) {
    // Enhanced format: [Magic:1][Type:1][ChunkID:1][ChunkNum:1][TotalChunks:1][DataLen:2][Data:variable][Checksum:1]
    // Data includes: [MessageType:1][Payload:variable] for first chunk, or just [Payload:variable] for subsequent chunks
    int dataLength = payload.length;
    Uint8List command = Uint8List(PACKET_HEADER_SIZE + dataLength + 1); // header + data + checksum
    command[0] = MAGIC_BYTE;        // Magic byte
    command[1] = PACKET_TYPE_DATA;  // Type: data
    command[2] = chunkId & 0xFF;    // Chunk ID
    command[3] = chunkNum & 0xFF;  // Chunk number
    command[4] = totalChunks & 0xFF; // Total chunks
    command[5] = dataLength & 0xFF;        // Data length (low byte)
    command[6] = (dataLength >> 8) & 0xFF; // Data length (high byte)
    
    // Copy payload
    for (int i = 0; i < payload.length; i++) {
      command[7 + i] = payload[i];
    }
    
    // Calculate XOR checksum (of all bytes except checksum)
    int checksum = 0;
    for (int i = 0; i < PACKET_HEADER_SIZE + dataLength; i++) {
      checksum ^= command[i];
    }
    command[PACKET_HEADER_SIZE + dataLength] = checksum;
    
    return command;
  }

  /// Create a complete command with chunking support
  static Uint8List _createCommand(int messageType, Uint8List payload) {
    return _createCommandWithChunking(messageType, 0, payload); // 0 = single packet
  }
  
  /// Create enhanced protocol command (matching firmware format)
  static Uint8List _createEnhancedCommand(int messageType, Uint8List payload) {
    // Enhanced format: [Magic:1][Type:1][ChunkID:1][ChunkNum:1][TotalChunks:1][DataLen:2][Data:variable][Checksum:1]
    // Data includes: [MessageType:1][Payload:variable]
    int dataLength = 1 + payload.length; // messageType + payload
    Uint8List command = Uint8List(PACKET_HEADER_SIZE + dataLength + 1); // header + data + checksum
    command[0] = MAGIC_BYTE;        // Magic byte
    command[1] = PACKET_TYPE_DATA;  // Type: data
    command[2] = 0x00;              // Chunk ID (0 for single packet)
    command[3] = 0x01;              // Chunk number (1 for single packet)
    command[4] = 0x01;              // Total chunks (1 for single packet)
    command[5] = dataLength & 0xFF;        // Data length (low byte)
    command[6] = (dataLength >> 8) & 0xFF; // Data length (high byte)
    
    // Copy message type and payload
    command[7] = messageType;
    for (int i = 0; i < payload.length; i++) {
      command[8 + i] = payload[i];
    }
    
    // Calculate XOR checksum (of all bytes except checksum)
    int checksum = 0;
    for (int i = 0; i < PACKET_HEADER_SIZE + dataLength; i++) {
      checksum ^= command[i];
    }
    command[PACKET_HEADER_SIZE + dataLength] = checksum;
    
    return command;
  }
  
  /// Create a command with chunking support
  static Uint8List _createCommandWithChunking(int messageType, int chunkInfo, Uint8List payload) {
    Uint8List command = Uint8List(1 + 2 + payload.length + 4);
    command[0] = messageType;
    command[1] = chunkInfo & 0xFF; // Chunk ID
    command[2] = (chunkInfo >> 8) & 0xFF; // Chunk Number
    
    for (int i = 0; i < payload.length; i++) {
      command[3 + i] = payload[i];
    }
    
    // Calculate CRC32 for the entire command (messageType + chunkInfo + payload)
    Uint8List dataForCrc = Uint8List(3 + payload.length);
    dataForCrc[0] = messageType;
    dataForCrc[1] = chunkInfo & 0xFF;
    dataForCrc[2] = (chunkInfo >> 8) & 0xFF;
    for (int i = 0; i < payload.length; i++) {
      dataForCrc[3 + i] = payload[i];
    }
    
    int crc32 = calculateCRC32(dataForCrc);
    Uint8List crcBytes = intToBytes(crc32);
    
    for (int i = 0; i < 4; i++) {
      command[3 + payload.length + i] = crcBytes[i];
    }
    
    return command;
  }
  
  /// Create chunked data for large responses
  static List<Uint8List> createChunkedResponse(int messageType, String data) {
    List<int> dataBytes = utf8.encode(data);
    List<Uint8List> chunks = [];
    
    if (dataBytes.length <= MAX_CHUNK_SIZE) {
      // Single packet
      chunks.add(_createCommandWithChunking(messageType, 0, Uint8List.fromList(dataBytes))); // 0 = single packet
    } else {
      // Multiple chunks
      int chunkId = DateTime.now().millisecondsSinceEpoch & 0xFF; // Simple chunk ID
      int totalChunks = (dataBytes.length / MAX_CHUNK_SIZE).ceil();
      
      for (int i = 0; i < totalChunks; i++) {
        int start = i * MAX_CHUNK_SIZE;
        int end = (start + MAX_CHUNK_SIZE).clamp(0, dataBytes.length);
        Uint8List chunkData = Uint8List(end - start);
        
        for (int j = start; j < end; j++) {
          chunkData[j - start] = dataBytes[j];
        }
        
        int chunkNumber = i + 1;
        if (i == totalChunks - 1) {
          chunkNumber = 0xFF; // Mark last chunk
        }
        
        int chunkInfo = chunkId | (chunkNumber << 8);
        chunks.add(_createCommandWithChunking(0xFE, chunkInfo, chunkData)); // 0xFE = chunk data
      }
    }
    
    return chunks;
  }

  /// Parse response from firmware (matching firmware packet format)
  static Map<String, dynamic> parseResponse(Uint8List data) {
    if (data.length < PACKET_HEADER_SIZE + 1) { // header + checksum
      throw Exception('Response too short');
    }

    // Extract packet fields (matching firmware format)
    // Format: [Magic:1][Type:1][ChunkID:1][ChunkNum:1][TotalChunks:1][DataLen:2][Data:variable][Checksum:1]
    int magic = data[0];
    int packetType = data[1];
    int chunkId = data[2];
    int chunkNumber = data[3];
    int totalChunks = data[4];
    int dataLength = data[5] | (data[6] << 8);  // Little-endian: 2 bytes
    
    // Validate magic byte
    if (magic != MAGIC_BYTE) {
      throw Exception('Invalid magic byte: 0x${magic.toRadixString(16)}');
    }
    
    // Validate packet type
    if (packetType != PACKET_TYPE_DATA) {
      throw Exception('Invalid packet type: 0x${packetType.toRadixString(16)}');
    }
    
    // Validate data length
    if (data.length < PACKET_HEADER_SIZE + dataLength + 1) {
      throw Exception('Packet length mismatch');
    }
    
    // Extract data and checksum
    Uint8List payload = data.sublist(PACKET_HEADER_SIZE, PACKET_HEADER_SIZE + dataLength);
    int receivedChecksum = data[PACKET_HEADER_SIZE + dataLength];
    
    // Calculate checksum (XOR of all bytes except checksum)
    int calculatedChecksum = 0;
    for (int i = 0; i < PACKET_HEADER_SIZE + dataLength; i++) {
      calculatedChecksum ^= data[i];
    }
    
    if (receivedChecksum != calculatedChecksum) {
      throw Exception('Invalid checksum: received 0x${receivedChecksum.toRadixString(16)}, calculated 0x${calculatedChecksum.toRadixString(16)}');
    }

    // Check if payload is binary (0x80-0xFF) or text
    bool isBinary = payload.isNotEmpty && payload[0] >= 0x80;
    
    Map<String, dynamic> result = {
      'packetType': packetType,
      'chunkId': chunkId,
      'chunkNumber': chunkNumber,
      'totalChunks': totalChunks,
      'isChunked': totalChunks > 1,
      'isLastChunk': chunkNumber == totalChunks,
      'isBinary': isBinary,
    };
    
    if (isBinary) {
      // Binary message: keep as Uint8List
      result['payloadBytes'] = payload;
      result['payload'] = ''; // Empty string for compatibility
    } else {
      // Text message: decode as UTF-8
      try {
        String payloadString = utf8.decode(payload);
        result['payload'] = payloadString;
        
        // Try to parse as JSON for single packet responses
        if (!result['isChunked']) {
          try {
            result['data'] = jsonDecode(payloadString);
          } catch (e) {
            result['data'] = payloadString;
          }
        }
      } catch (e) {
        // If UTF-8 decode fails, treat as binary
        result['payloadBytes'] = payload;
        result['payload'] = '';
        result['isBinary'] = true;
      }
    }
    
    return result;
  }

  /// Create save to signals with custom name command
  static Uint8List createSaveToSignalsWithNameCommand(String sourcePath, String targetName, {int pathType = 0, DateTime? preserveDate}) {
    List<int> sourcePathBytes = utf8.encode(sourcePath);
    List<int> targetNameBytes = utf8.encode(targetName);
    // Добавляем 4 байта для даты (Unix timestamp), если она указана
    int dateBytes = preserveDate != null ? 4 : 0;
    Uint8List payload = Uint8List(3 + sourcePathBytes.length + targetNameBytes.length + dateBytes);
    
    payload[0] = sourcePathBytes.length;
    payload[1] = targetNameBytes.length;
    payload[2] = pathType; // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, 2=/DATA/PRESETS, etc.
    
    // Copy source path
    for (int i = 0; i < sourcePathBytes.length; i++) {
      payload[3 + i] = sourcePathBytes[i];
    }
    
    // Copy target name
    for (int i = 0; i < targetNameBytes.length; i++) {
      payload[3 + sourcePathBytes.length + i] = targetNameBytes[i];
    }
    
    // Add date if provided (Unix timestamp in seconds, 4 bytes little-endian)
    if (preserveDate != null) {
      final timestamp = preserveDate.millisecondsSinceEpoch ~/ 1000; // Convert to seconds
      final offset = 3 + sourcePathBytes.length + targetNameBytes.length;
      payload[offset] = timestamp & 0xFF;
      payload[offset + 1] = (timestamp >> 8) & 0xFF;
      payload[offset + 2] = (timestamp >> 16) & 0xFF;
      payload[offset + 3] = (timestamp >> 24) & 0xFF;
    }
    
    return _createEnhancedCommand(MSG_SAVE_TO_SIGNALS_WITH_NAME, payload);
  }

  /// Create frequency search command
  static Uint8List createFrequencySearchCommand(int module, int minRssi, {bool isBackground = false}) {
    Uint8List payload = Uint8List(3);
    payload[0] = module;
    payload[1] = minRssi; // RSSI threshold (-100 to 0)
    payload[2] = isBackground ? 1 : 0; // Background scanner flag
    
    return _createEnhancedCommand(MSG_FREQUENCY_SEARCH, payload);
  }

  /// Create set time command (Unix timestamp in seconds, 4 bytes little-endian)
  static Uint8List createSetTimeCommand(DateTime dateTime) {
    final timestamp = dateTime.millisecondsSinceEpoch ~/ 1000; // Convert to seconds
    Uint8List payload = Uint8List(4);
    payload[0] = timestamp & 0xFF;
    payload[1] = (timestamp >> 8) & 0xFF;
    payload[2] = (timestamp >> 16) & 0xFF;
    payload[3] = (timestamp >> 24) & 0xFF;
    
    return _createEnhancedCommand(MSG_SET_TIME, payload);
  }

  /// Create start jam command
  /// Format: module(1) + frequency(4) + modulation(1) + deviation(4) + power(1) + patternType(1) + maxDurationMs(4) + cooldownMs(4) + [customPatternLen(1) + customPattern]
  /// Create startJam command
  /// Format: module(1) + frequency(4) + power(1) + patternType(1) + maxDurationMs(4) + cooldownMs(4) + [customPatternLen(1) + customPattern]
  static Uint8List createStartJamCommand({
    required int module,
    required double frequency,
    int power = 7, // 0-7
    int patternType = 0, // 0=Random, 1=Alternating, 2=Continuous, 3=Custom
    int maxDurationMs = 60000, // 60 seconds default
    int cooldownMs = 5000, // 5 seconds default
    List<int>? customPattern, // Optional custom pattern bytes
  }) {
    int baseSize = 15; // module(1) + frequency(4) + power(1) + patternType(1) + maxDurationMs(4) + cooldownMs(4)
    int customPatternSize = 0;
    if (patternType == 3 && customPattern != null) {
      customPatternSize = 1 + customPattern.length; // length byte + pattern bytes
    }
    
    Uint8List payload = Uint8List(baseSize + customPatternSize);
    int offset = 0;
    
    // module (1 byte)
    payload[offset++] = module;
    
    // frequency (4 bytes, float, little-endian)
    Uint8List freqBytes = _floatToBytes(frequency);
    for (int i = 0; i < 4; i++) {
      payload[offset++] = freqBytes[i];
    }
    
    // power (1 byte, 0-7)
    payload[offset++] = power.clamp(0, 7);
    
    // patternType (1 byte, 0-3)
    payload[offset++] = patternType.clamp(0, 3);
    
    // maxDurationMs (4 bytes, uint32, little-endian)
    payload[offset++] = maxDurationMs & 0xFF;
    payload[offset++] = (maxDurationMs >> 8) & 0xFF;
    payload[offset++] = (maxDurationMs >> 16) & 0xFF;
    payload[offset++] = (maxDurationMs >> 24) & 0xFF;
    
    // cooldownMs (4 bytes, uint32, little-endian)
    payload[offset++] = cooldownMs & 0xFF;
    payload[offset++] = (cooldownMs >> 8) & 0xFF;
    payload[offset++] = (cooldownMs >> 16) & 0xFF;
    payload[offset++] = (cooldownMs >> 24) & 0xFF;
    
    // customPattern (optional)
    if (patternType == 3 && customPattern != null) {
      payload[offset++] = customPattern.length;
      for (int i = 0; i < customPattern.length; i++) {
        payload[offset++] = customPattern[i];
      }
    }
    
    return _createEnhancedCommand(MSG_START_JAM, payload);
  }
}
