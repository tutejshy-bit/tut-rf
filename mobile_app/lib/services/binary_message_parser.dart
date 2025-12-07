import 'dart:typed_data';
import 'dart:convert';

/// Binary message types from firmware (0x80-0xFF)
enum BinaryMessageType {
  modeSwitch(0x80),
  status(0x81),
  heartbeat(0x82),
  signalDetected(0x90),
  signalRecorded(0x91),
  signalSent(0x92),
  fileContent(0xA0),  // RAW file content (NO JSON!)
  fileList(0xA1),     // File list (binary format: [0xA1][pathLen:1][path][jsonData...]) - streaming format, no jsonLength
  error(0xF0),
  lowMemory(0xF1);

  final int value;
  const BinaryMessageType(this.value);

  static BinaryMessageType? fromValue(int value) {
    for (var type in BinaryMessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// File list message (variable length)
/// Format: [0xA1][pathLen:1][path:variable][jsonLength:4][jsonData:variable]
class BinaryFileList {
  final String path;
  final int jsonLength;
  final String jsonData;

  BinaryFileList({
    required this.path,
    required this.jsonLength,
    required this.jsonData,
  });

  factory BinaryFileList.parse(Uint8List data) {
    if (data.length < 3) {
      throw Exception('Invalid BinaryFileList data length: ${data.length}');
    }

    int offset = 1; // Skip 0xA1
    int pathLen = data[offset++];
    
    if (data.length < 2 + pathLen) {
      throw Exception('Invalid BinaryFileList: insufficient data for path');
    }
    
    String path = String.fromCharCodes(data.sublist(offset, offset + pathLen));
    offset += pathLen;
    
    // ESP32 sends JSON data directly without jsonLength field (streaming format)
    // Read all remaining data as JSON (from offset to end)
    if (data.length < offset) {
      throw Exception('Invalid BinaryFileList: insufficient data for JSON content');
    }
    
    // Read all remaining data as JSON (no jsonLength field in streaming format)
    String jsonData = String.fromCharCodes(data.sublist(offset));
    int jsonLength = jsonData.length;

    return BinaryFileList(
      path: path,
      jsonLength: jsonLength,
      jsonData: jsonData,
    );
  }

  Map<String, dynamic> toJson() {
    // Parse the JSON string and return as Map
    try {
      final jsonMap = jsonDecode(jsonData);
      return jsonMap;
    } catch (e) {
      // If JSON parsing fails, return error
      return {
        'action': 'list',
        'error': 'Failed to parse JSON: $e',
        'files': [],
      };
    }
  }
}

/// File content message (variable length)
/// Format: [0xA0][pathLen:1][path:variable][fileSize:4][content:variable]
class BinaryFileContent {
  final String path;
  final int fileSize;
  final Uint8List content;

  BinaryFileContent({
    required this.path,
    required this.fileSize,
    required this.content,
  });

  factory BinaryFileContent.parse(Uint8List data) {
    if (data.length < 6) {
      throw Exception('Invalid BinaryFileContent data length: ${data.length}');
    }

    int offset = 1; // Skip 0xA0
    int pathLen = data[offset++];
    
    if (data.length < 2 + pathLen + 4) {
      throw Exception('Invalid BinaryFileContent: insufficient data for path and size');
    }
    
    String path = String.fromCharCodes(data.sublist(offset, offset + pathLen));
    offset += pathLen;
    
    // Read file size (4 bytes, little-endian)
    int fileSize = data[offset] | 
                   (data[offset + 1] << 8) | 
                   (data[offset + 2] << 16) | 
                   (data[offset + 3] << 24);
    offset += 4;
    
    // Read file content
    Uint8List content = data.sublist(offset);

    return BinaryFileContent(
      path: path,
      fileSize: fileSize,
      content: content,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': 'load',
      'path': path,
      'size': fileSize,
      'success': true,
      'content': String.fromCharCodes(content), // Convert bytes to string
    };
  }
}

/// Mode switch message (4 bytes)
class BinaryModeSwitch {
  final int module;
  final int currentMode;
  final int previousMode;

  BinaryModeSwitch({
    required this.module,
    required this.currentMode,
    required this.previousMode,
  });

  factory BinaryModeSwitch.parse(Uint8List data) {
    if (data.length < 4) {
      throw Exception('Invalid BinaryModeSwitch data length: ${data.length}');
    }

    return BinaryModeSwitch(
      module: data[1],
      currentMode: data[2],
      previousMode: data[3],
    );
  }

  String getModeString(int mode) {
    switch (mode) {
      case 0: return 'Idle';
      case 1: return 'DetectSignal';
      case 2: return 'RecordSignal';
      default: return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module.toString(),
      'mode': getModeString(currentMode),
      'previousMode': getModeString(previousMode),
    };
  }
}

/// Status message with CC1101 registers (102 bytes)
/// Structure: [type:1][mode0:1][mode1:1][numRegs:1][heap:4][regs0:47][regs1:47]
class BinaryStatus {
  final int module0Mode;
  final int module1Mode;
  final int numRegisters;
  final int freeHeap;
  final List<int> module0Registers;
  final List<int> module1Registers;

  BinaryStatus({
    required this.module0Mode,
    required this.module1Mode,
    required this.numRegisters,
    required this.freeHeap,
    required this.module0Registers,
    required this.module1Registers,
  });

  factory BinaryStatus.parse(Uint8List data) {
    if (data.length < 102) {
      throw Exception('Invalid BinaryStatus data length: ${data.length}, expected 102');
    }

    // Parse little-endian uint32 for freeHeap (offset 4, length 4)
    final byteData = ByteData.sublistView(data);
    final freeHeap = byteData.getUint32(4, Endian.little);

    return BinaryStatus(
      module0Mode: data[1],
      module1Mode: data[2],
      numRegisters: data[3],
      freeHeap: freeHeap,
      module0Registers: data.sublist(8, 55).toList(),  // 8..54 = 47 bytes
      module1Registers: data.sublist(55, 102).toList(), // 55..101 = 47 bytes
    );
  }

  String getModeString(int mode) {
    switch (mode) {
      case 0: return 'Idle';
      case 1: return 'DetectSignal';
      case 2: return 'RecordSignal';
      default: return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    // Convert to format compatible with existing code
    return {
      'device': {
        'freeHeap': freeHeap,
      },
      'cc1101': [
        {
          'id': 0,
          'mode': getModeString(module0Mode),
          'settings': _registersToHexString(module0Registers),
        },
        {
          'id': 1,
          'mode': getModeString(module1Mode),
          'settings': _registersToHexString(module1Registers),
        },
      ],
    };
  }

  String _registersToHexString(List<int> registers) {
    final buffer = StringBuffer();
    for (int i = 0; i < registers.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(i.toRadixString(16).padLeft(2, '0').toUpperCase());
      buffer.write(' ');
      buffer.write(registers[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }
}

/// Heartbeat message (5 bytes)
class BinaryHeartbeat {
  final int uptimeMs;

  BinaryHeartbeat({required this.uptimeMs});

  factory BinaryHeartbeat.parse(Uint8List data) {
    if (data.length < 5) {
      throw Exception('Invalid BinaryHeartbeat data length: ${data.length}');
    }

    final byteData = ByteData.sublistView(data);
    return BinaryHeartbeat(
      uptimeMs: byteData.getUint32(1, Endian.little),
    );
  }
}

/// Binary message parser utility
class BinaryMessageParser {
  /// Check if data is a binary message (first byte is 0x80-0xFF)
  static bool isBinaryMessage(Uint8List data) {
    if (data.isEmpty) return false;
    return data[0] >= 0x80;
  }

  /// Parse binary message and return as Map compatible with existing code
  static Map<String, dynamic>? parseBinaryMessage(Uint8List data) {
    if (data.isEmpty) return null;

    final messageType = BinaryMessageType.fromValue(data[0]);
    if (messageType == null) return null;

    try {
      switch (messageType) {
        case BinaryMessageType.modeSwitch:
          final msg = BinaryModeSwitch.parse(data);
          return {
            'type': 'ModeSwitch',
            'data': msg.toJson(),
          };

        case BinaryMessageType.status:
          final msg = BinaryStatus.parse(data);
          return {
            'type': 'State',
            'data': msg.toJson(),
          };

        case BinaryMessageType.heartbeat:
          final msg = BinaryHeartbeat.parse(data);
          return {
            'type': 'Heartbeat',
            'data': {'uptime': msg.uptimeMs},
          };

        case BinaryMessageType.fileContent:
          final msg = BinaryFileContent.parse(data);
          return {
            'type': 'FileSystem',
            'data': msg.toJson(),
          };

        case BinaryMessageType.fileList:
          final msg = BinaryFileList.parse(data);
          // Return the parsed JSON directly (it already contains action, files, etc.)
          return {
            'type': 'FileSystem',
            'data': msg.toJson(),
          };

        default:
          print('Unsupported binary message type: 0x${data[0].toRadixString(16)}');
          return null;
      }
    } catch (e) {
      print('Error parsing binary message: $e');
      return null;
    }
  }
}

