import 'dart:typed_data';

/// Binary message types from firmware (0x80-0xFF)
enum BinaryMessageType {
  modeSwitch(0x80),
  status(0x81),
  heartbeat(0x82),
  signalDetected(0x90),
  signalRecorded(0x91),
  signalSent(0x92),
  signalSendError(0x93),
  frequencySearch(0x94),
  fileContent(0xA0), // RAW file content (NO JSON!)
  fileList(0xA1),    // File list BINARY
  directoryTree(0xA2),
  fileActionResult(0xA3),
  error(0xF0),
  lowMemory(0xF1),
  commandSuccess(0xF2),
  commandError(0xF3);

  final int value;
  const BinaryMessageType(this.value);

  static BinaryMessageType? fromValue(int value) {
    for (var type in BinaryMessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// File entry from binary format
class BinaryFileEntry {
  final String name;
  final bool isDirectory;
  final int size;       // Only for files
  final int timestamp;  // Only for files (Unix timestamp in seconds)

  BinaryFileEntry({
    required this.name,
    required this.isDirectory,
    this.size = 0,
    this.timestamp = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': isDirectory ? 'directory' : 'file',
      'size': size,
      'date': timestamp.toString(),
    };
  }
}

/// File list message - STREAMING BINARY PROTOCOL (no JSON!)
/// 
/// Format (each message):
/// [0xA1][pathLen:1][path:pathLen][flags:1][totalFiles:2][fileCount:1][files...]
///
/// flags byte:
///   bit 0 (0x01): hasMore - 1=more messages coming, 0=last message
///   bit 7 (0x80): error - if set, bits 0-6 contain error code
///
/// totalFiles: total number of files in directory (for progress calculation)
/// fileCount: number of files in THIS message
///
/// For each file:
///   [nameLen:1][name:nameLen][fileFlags:1]
///   If file (fileFlags & 0x01 == 0):
///     [size:4][date:4]  (little-endian)
class BinaryFileList {
  final String path;
  final bool hasMore;         // true if more messages coming
  final bool isError;         // true if this is an error response
  final int errorCode;        // Error code (valid only if isError)
  final int totalFiles;       // Total files in directory (for progress)
  final List<BinaryFileEntry> files;

  BinaryFileList({
    required this.path,
    required this.hasMore,
    required this.isError,
    required this.errorCode,
    required this.totalFiles,
    required this.files,
  });

  factory BinaryFileList.parse(Uint8List data) {
    if (data.length < 6) {
      throw Exception('Invalid BinaryFileList data length: ${data.length}');
    }

    int offset = 1; // Skip 0xA1
    int pathLen = data[offset++];
    
    // Header: type + pathLen + path + flags + totalFiles(2) + fileCount
    if (data.length < 2 + pathLen + 4) {
      throw Exception('Invalid BinaryFileList: insufficient data for header');
    }
    
    String path = String.fromCharCodes(data.sublist(offset, offset + pathLen));
    offset += pathLen;
    
    int flags = data[offset++];
    bool hasMore = (flags & 0x01) != 0;
    bool isError = (flags & 0x80) != 0;
    int errorCode = isError ? (flags & 0x7F) : 0;
    
    // Total files (2 bytes, little-endian)
    int totalFiles = data[offset] | (data[offset + 1] << 8);
    offset += 2;
    
    int fileCount = data[offset++];
    
    // Parse file entries
    List<BinaryFileEntry> files = [];
    
    if (!isError) {
      for (int i = 0; i < fileCount && offset < data.length; i++) {
        if (offset >= data.length) break;
        
        int nameLen = data[offset++];
        if (offset + nameLen > data.length) break;
        
        String name = String.fromCharCodes(data.sublist(offset, offset + nameLen));
        offset += nameLen;
        
        if (offset >= data.length) break;
        int fileFlags = data[offset++];
        bool isDirectory = (fileFlags & 0x01) != 0;
        
        int size = 0;
        int timestamp = 0;
        
        if (!isDirectory) {
          if (offset + 8 > data.length) break;
          // Read size (4 bytes, little-endian)
          size = data[offset] | 
                 (data[offset + 1] << 8) | 
                 (data[offset + 2] << 16) | 
                 (data[offset + 3] << 24);
          offset += 4;
          // Read date (4 bytes, little-endian)
          timestamp = data[offset] | 
                      (data[offset + 1] << 8) | 
                      (data[offset + 2] << 16) | 
                      (data[offset + 3] << 24);
          offset += 4;
        }
        
        files.add(BinaryFileEntry(
          name: name,
          isDirectory: isDirectory,
          size: size,
          timestamp: timestamp,
        ));
      }
    }

    return BinaryFileList(
      path: path,
      hasMore: hasMore,
      isError: isError,
      errorCode: errorCode,
      totalFiles: totalFiles,
      files: files,
    );
  }

  /// Convert to format compatible with existing code
  Map<String, dynamic> toJson() {
    if (isError) {
      return {
        'action': 'list',
        'error': _getErrorMessage(errorCode),
        'files': [],
        'streaming': false,
        'totalFiles': 0,
      };
    }
    
    return {
      'action': 'list',
      'files': files.map((f) => f.toJson()).toList(),
      'streaming': hasMore,
      'totalFiles': totalFiles,
    };
  }
  
  static String _getErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1: return 'Insufficient memory';
      case 2: return 'Failed to create directory';
      case 3: return 'Failed to open directory';
      case 4: return 'Path is not a directory';
      case 5: return 'Unknown error';
      default: return 'Error code: $errorCode';
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

/// Signal detected message (12 bytes)
class BinarySignalDetected {
  final int module;
  final int frequency;
  final int rssi;

  BinarySignalDetected({
    required this.module,
    required this.frequency,
    required this.rssi,
  });

  factory BinarySignalDetected.parse(Uint8List data) {
    if (data.length < 12) {
      throw Exception('Invalid BinarySignalDetected data length: ${data.length}');
    }

    final byteData = ByteData.sublistView(data);
    return BinarySignalDetected(
      module: data[1],
      frequency: byteData.getUint32(4, Endian.little),
      rssi: byteData.getInt16(8, Endian.little),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module.toString(),
      'frequency': (frequency / 1000000).toStringAsFixed(2),
      'rssi': rssi.toString(),
      'isBackgroundScanner': 'false', // Default for now
    };
  }
}

/// Signal recorded message
class BinarySignalRecorded {
  final int module;
  final String filename;

  BinarySignalRecorded({
    required this.module,
    required this.filename,
  });

  factory BinarySignalRecorded.parse(Uint8List data) {
    if (data.length < 3) {
      throw Exception('Invalid BinarySignalRecorded data length: ${data.length}');
    }

    int module = data[1];
    int nameLen = data[2];
    String name = String.fromCharCodes(data.sublist(3, 3 + nameLen));

    return BinarySignalRecorded(
      module: module,
      filename: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'module': module,
    };
  }
}

/// Signal sent message
class BinarySignalSent {
  final int module;
  final String filename;

  BinarySignalSent({
    required this.module,
    required this.filename,
  });

  factory BinarySignalSent.parse(Uint8List data) {
    int module = data[1];
    int nameLen = data[2];
    String name = String.fromCharCodes(data.sublist(3, 3 + nameLen));

    return BinarySignalSent(module: module, filename: name);
  }

  Map<String, dynamic> toJson() {
    return {
      'file': filename,
      'module': module,
    };
  }
}

/// File action result message
class BinaryFileActionResult {
  final int action;
  final bool success;
  final int errorCode;
  final String path;

  BinaryFileActionResult({
    required this.action,
    required this.success,
    required this.errorCode,
    required this.path,
  });

  factory BinaryFileActionResult.parse(Uint8List data) {
    int action = data[1];
    bool success = data[2] == 0;
    int errorCode = data[3];
    int pathLen = data[4];
    String path = '';
    if (pathLen > 0) {
      path = String.fromCharCodes(data.sublist(5, 5 + pathLen));
    }

    return BinaryFileActionResult(
      action: action,
      success: success,
      errorCode: errorCode,
      path: path,
    );
  }

  String getActionString() {
    switch (action) {
      case 1: return 'delete';
      case 2: return 'rename';
      case 3: return 'create-directory';
      case 4: return 'copy';
      case 5: return 'move';
      case 6: return 'tree';
      case 7: return 'load';
      default: return 'unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'action': getActionString(),
      'success': success,
      'path': path,
      'error': success ? null : _getErrorMessage(errorCode),
    };
  }

  static String _getErrorMessage(int code) {
    switch (code) {
      case 1: return 'Insufficient data';
      case 2: return 'Path length mismatch';
      case 3: return 'Not found';
      case 4: return 'Delete failed';
      case 5: return 'To length missing';
      case 6: return 'Rename failed';
      case 7: return 'Mkdir failed';
      case 13: return 'Failed to open file';
      case 14: return 'Path too long';
      case 15: return 'BLE adapter not found';
      default: return 'Error $code';
    }
  }
}

/// Directory tree message - STREAMING BINARY PROTOCOL
/// 
/// Format (each message):
/// [0xA2][pathType:1][flags:1][totalDirs:2][dirCount:2][paths...]
///
/// flags byte:
///   bit 0 (0x01): hasMore - 1=more messages coming, 0=last message
///   bit 7 (0x80): error - if set, bits 0-6 contain error code
///
/// totalDirs: total number of directories (for progress calculation)
/// dirCount: number of directories in THIS message (2 bytes, little-endian)
///
/// For each path:
///   [pathLen:1][path:pathLen]
class BinaryDirectoryTree {
  final int pathType;
  final bool hasMore;         // true if more messages coming
  final bool isError;         // true if this is an error response
  final int errorCode;        // Error code (valid only if isError)
  final int totalDirs;        // Total directories (for progress)
  final List<String> paths;

  BinaryDirectoryTree({
    required this.pathType,
    required this.hasMore,
    required this.isError,
    required this.errorCode,
    required this.totalDirs,
    required this.paths,
  });

  factory BinaryDirectoryTree.parse(Uint8List data) {
    if (data.length < 7) {
      throw Exception('Invalid BinaryDirectoryTree data length: ${data.length}');
    }

    int pathType = data[1];
    int flags = data[2];
    bool hasMore = (flags & 0x01) != 0;
    bool isError = (flags & 0x80) != 0;
    int errorCode = isError ? (flags & 0x7F) : 0;
    
    // Total dirs (2 bytes, little-endian)
    int totalDirs = data[3] | (data[4] << 8);
    
    // Dir count (2 bytes, little-endian)
    int dirCount = data[5] | (data[6] << 8);
    
    int offset = 7;
    List<String> paths = [];

    if (!isError) {
      for (int i = 0; i < dirCount && offset < data.length; i++) {
        if (offset >= data.length) break;
        
        int pathLen = data[offset++];
        if (offset + pathLen > data.length) break;
        
        paths.add(String.fromCharCodes(data.sublist(offset, offset + pathLen)));
        offset += pathLen;
      }
    }

    return BinaryDirectoryTree(
      pathType: pathType,
      hasMore: hasMore,
      isError: isError,
      errorCode: errorCode,
      totalDirs: totalDirs,
      paths: paths,
    );
  }

  Map<String, dynamic> toJson() {
    if (isError) {
      return {
        'pathType': pathType,
        'error': _getErrorMessage(errorCode),
        'paths': [],
        'streaming': false,
        'totalDirs': 0,
      };
    }
    
    return {
      'pathType': pathType,
      'paths': paths,
      'streaming': hasMore,
      'totalDirs': totalDirs,
    };
  }
  
  static String _getErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1: return 'Insufficient memory';
      case 5: return 'Unknown error';
      default: return 'Error code: $errorCode';
    }
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
      case 3: return 'Transmitting';
      case 4: return 'Analyzing';
      case 5: return 'Jamming';
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
      case 3: return 'Transmitting';
      case 4: return 'Analyzing';
      case 5: return 'Jamming';
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

        case BinaryMessageType.directoryTree:
          final msg = BinaryDirectoryTree.parse(data);
          return {
            'type': 'DirectoryTree',
            'data': msg.toJson(),
          };

        case BinaryMessageType.signalDetected:
          final msg = BinarySignalDetected.parse(data);
          return {
            'type': 'SignalDetected',
            'data': msg.toJson(),
          };

        case BinaryMessageType.signalRecorded:
          final msg = BinarySignalRecorded.parse(data);
          return {
            'type': 'SignalRecorded',
            'data': msg.toJson(),
          };

        case BinaryMessageType.signalSent:
          final msg = BinarySignalSent.parse(data);
          return {
            'type': 'SignalSent',
            'data': msg.toJson(),
          };

        case BinaryMessageType.signalSendError:
          // Format: [MSG_SIGNAL_SEND_ERROR][errorCode] or [MSG_SIGNAL_SEND_ERROR][errorCode][filenameLength][filename...]
          int code = data.length > 1 ? data[1] : 0;
          String errorMessage;
          switch (code) {
            case 1:
              errorMessage = 'Insufficient data';
              break;
            case 2:
              errorMessage = 'Path length mismatch';
              break;
            case 3:
              errorMessage = 'Failed to post task';
              break;
            case 4:
              errorMessage = 'No idle module available';
              break;
            case 5:
              errorMessage = 'Module is not idle';
              break;
            default:
              errorMessage = 'Error code: $code';
          }
          // If there's more data, it might be filename
          String? filename;
          if (data.length > 2) {
            int filenameLength = data[2];
            if (data.length >= 3 + filenameLength) {
              filename = String.fromCharCodes(data.sublist(3, 3 + filenameLength));
            }
          }
          return {
            'type': 'SignalSendingError',
            'data': {
              'errorCode': code,
              'error': errorMessage,
              if (filename != null) 'filename': filename,
            },
          };

        case BinaryMessageType.fileActionResult:
          final msg = BinaryFileActionResult.parse(data);
          return {
            'type': 'FileSystem',
            'data': msg.toJson(),
          };

        case BinaryMessageType.commandSuccess:
          return {
            'type': 'CommandResult',
            'data': {'success': true},
          };

        case BinaryMessageType.commandError:
          return {
            'type': 'CommandResult',
            'data': {'success': false, 'errorCode': data.length > 1 ? data[1] : 0},
          };

        case BinaryMessageType.error:
          int code = data.length > 1 ? data[1] : 0;
          String msg = '';
          if (data.length > 2) {
            msg = String.fromCharCodes(data.sublist(2));
          }
          return {
            'type': 'error',
            'error': msg.isNotEmpty ? msg : 'Error $code',
            'errorCode': code,
          };

        case BinaryMessageType.lowMemory:
          return {
            'type': 'error',
            'error': 'Device low memory',
            'errorCode': 0xF1,
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

