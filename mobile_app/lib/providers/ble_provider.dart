import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
import '../models/detected_signal.dart';
import '../models/directory_tree_node.dart';
import 'firmware_protocol.dart';
import '../services/signal_processing/signal_data.dart';
import '../services/signal_generators/signal_generator_factory.dart';
import '../services/signal_generators/base_signal_generator.dart';
import '../services/file_parsers/file_parser_factory.dart';
import '../services/cc1101/cc1101_calculator.dart';
import '../services/cc1101/cc1101_values.dart';
import '../services/binary_message_parser.dart';
// import 'log_provider.dart'; // Unused import removed

class BleProvider extends ChangeNotifier {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? txCharacteristic;
  BluetoothCharacteristic? rxCharacteristic;
  
  // Callback для логирования
  Function(String level, String message, {String? details})? _logCallback;
  
  // File reading state
  String? _currentFileContent;
  Completer<String>? _pendingFileReadCompleter;
  bool isLoadingFileContent = false;
  double fileContentProgress = 0.0;
  
  // File system operations completers
  Completer<Map<String, dynamic>>? _pendingRenameCompleter;
  Completer<Map<String, dynamic>>? _pendingDirectoryTreeCompleter;
  
  // Метод для установки callback логирования
  void setLogCallback(Function(String level, String message, {String? details}) callback) {
    _logCallback = callback;
  }
  
  // Вспомогательный метод для логирования
  void _log(String level, String message, {String? details}) {
    _logCallback?.call(level, message, details: details);
  }
  
  bool isScanning = false;
  bool isConnected = false;
  List<ScanResult> scanResults = [];
  String statusMessage = ''; // Will be set with localized strings
  String lastCommandMessage = ''; // Отдельное поле для сообщений о командах
  
  // List of supported device names (fallback)
  static const List<String> supportedDeviceNames = [
    'ESP32_CC1101',
    'EvilCrow_RF2',
    'ESP32_Binary',
    'ESP32',
  ];
  
  // Our custom Service UUID for device identification
  static const String evilCrowServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  
  // Nordic UART Service (NUS) UUIDs
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String txUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // Write characteristic
  static const String rxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // Notify characteristic
  
  // EvilCrow Manufacturer ID and Device ID
  static const int evilCrowManufacturerId = 0x1234;
  static const List<int> evilCrowDeviceId = [0x01, 0x02, 0x03, 0x04];
  List<FileItem> fileList = [];
  String currentPath = '/';
  int currentPathType = 0; // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, 2=/DATA/PRESETS, 3=/DATA/TEMP
  bool isLoadingFiles = false;
  double fileListProgress = 0.0; // Progress for file list loading (0.0 to 1.0)
  
  // Scanner state
  List<DetectedSignal> detectedSignals = [];
  Map<String, double> frequencySpectrum = {};
  int selectedModule = 0;
  int rssiThreshold = -100;
  
  // Device status
  Map<String, dynamic>? deviceStatus;
  int? freeHeap;
  List<Map<String, dynamic>>? cc1101Modules;
  
  // Recorded files
  List<Map<String, dynamic>> recordedRuntimeFiles = [];
  
  // Recording state for each module
  Map<int, bool> isRecording = {0: false, 1: false}; // Module -> is recording
  Map<int, bool> isFrequencySearching = {0: false, 1: false}; // Module -> is frequency searching
  Map<int, bool> isJamming = {0: false, 1: false}; // Module -> is jamming
  
  // Кеш для списков файлов по путям
  Map<String, List<FileItem>> _fileCache = {};
  Map<String, DateTime> _cacheTimestamps = {}; // Время последнего обновления для каждого пути
  
  // Streaming file list buffer (for accumulating files from multiple messages)
  List<FileItem> _streamingFileBuffer = [];
  bool _isStreamingFileList = false;
  int _streamingTotalFiles = 0;  // Total files expected (for progress)
  
  // Directory tree streaming state
  List<String> _streamingDirectoryTreeBuffer = [];
  bool _isStreamingDirectoryTree = false;
  int _streamingTotalDirs = 0;  // Total directories expected (for progress)
  
  // Защита от множественных команд
  bool _isCommandInProgress = false;
  bool _isWriting = false; // Flag to prevent concurrent BLE writes
  DateTime? _lastCommandTime;
  static const Duration _commandCooldown = Duration(milliseconds: 200);
  
  // Таймауты для команд
  Timer? _commandTimeout;
  static const Duration _commandTimeoutDuration = Duration(seconds: 15);
  
  // Таймаут для загрузки списка файлов
  Timer? _fileListTimeout;
  static const Duration _fileListTimeoutDuration = Duration(seconds: 15);
  
  // Буферы для чанков
  // Old chunk buffers removed - using firmware protocol now
  
  // Состояние текущего чанка
  // Old chunk state variables removed - using firmware protocol now
  
  // Old chunk processing variables removed - using firmware protocol now
  
  
  // Target device name - updated to match firmware
  static const String targetDeviceName = 'ESP32_CC1101';
  
  // Known device storage
  String? _knownDeviceId;
  static const String _deviceIdKey = 'known_device_id';
  
  // Quick connect to known device
  Future<void> quickConnect() async {
    if (isConnected || isScanning) return;
    
    try {
      // First try: Connect to known device if we have one
      if (_knownDeviceId != null) {
        print('Attempting direct connection to known device: $_knownDeviceId');
        statusMessage = 'connectingToKnownDevice'; // Key for localization
        notifyListeners();
        
        try {
          BluetoothDevice knownDevice = BluetoothDevice.fromId(_knownDeviceId!);
          print('Created device object for known device: ${knownDevice.name} (${knownDevice.id})');
          await connectToDevice(knownDevice);
          return; // Success, exit early
        } catch (e) {
          print('Direct connection failed: $e');
          // Clear the known device if it's no longer available
          await _clearKnownDevice();
        }
      }
      
      // Second try: Scan for target device
      print('Scanning for target device: $targetDeviceName');
      statusMessage = 'Scanning for device...';
      notifyListeners();
      
      await startScan();
      
      // Wait for scan results (reduced timeout)
      await Future.delayed(const Duration(seconds: 2));
      
      // Look for target device in supported scan results
      List<ScanResult> supportedDevices = supportedScanResults;
      for (var result in supportedDevices) {
        if (result.device.name == targetDeviceName) {
          print('Found target device: ${result.device.id}');
          await connectToDevice(result.device);
          // Save this device for future quick connections
          await saveKnownDevice(result.device.id.toString());
          break;
        }
      }
      
      // If no device found, show error
      if (!isConnected) {
        statusMessage = 'Device not found. Make sure it\'s powered on and nearby.';
        notifyListeners();
      }
      
    } catch (e) {
      statusMessage = 'Connection error: $e';
      notifyListeners();
    }
  }

  BleProvider() {
    _initializeBle();
    _loadKnownDevice();
  }

  Future<void> _initializeBle() async {
    // Request permissions
    await requestPermissions();
    
    // Listen to Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        // Don't show "Bluetooth enabled" message
        statusMessage = '';
      } else {
        statusMessage = 'Bluetooth disabled';
        isConnected = false;
        connectedDevice = null;
      }
      notifyListeners();
    });
  }
  
  Future<void> _loadKnownDevice() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _knownDeviceId = prefs.getString(_deviceIdKey);
      if (_knownDeviceId != null) {
        print('Loaded known device ID: $_knownDeviceId');
      }
    } catch (e) {
      print('Error loading known device: $e');
    }
  }
  
  Future<void> saveKnownDevice(String deviceId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, deviceId);
      _knownDeviceId = deviceId;
      print('Saved known device ID: $deviceId');
    } catch (e) {
      print('Error saving known device: $e');
    }
  }
  
  Future<void> _clearKnownDevice() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      _knownDeviceId = null;
      print('Cleared known device ID');
    } catch (e) {
      print('Error clearing known device: $e');
    }
  }
  
  /// Clear saved device cache
  Future<void> clearDeviceCache() async {
    await _clearKnownDevice();
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    // Basic Bluetooth permissions
    if (await Permission.bluetooth.isDenied) {
      await Permission.bluetooth.request();
    }
    
    // Android 12+ specific permissions
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    
    if (await Permission.bluetoothAdvertise.isDenied) {
      await Permission.bluetoothAdvertise.request();
    }
    
    // Location permission (required for scanning)
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
    
    // Check if all permissions are granted
    bool allGranted = await Permission.bluetooth.isGranted &&
                      await Permission.bluetoothScan.isGranted &&
                      await Permission.bluetoothConnect.isGranted &&
                      await Permission.location.isGranted;
    
    if (!allGranted) {
      statusMessage = 'Some permissions denied. Bluetooth may not work properly.';
      notifyListeners();
    } else {
      statusMessage = 'All permissions granted. Bluetooth ready.';
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    if (isScanning) return;
    
    // Check permissions before scanning
    if (!await _checkScanPermissions()) {
      statusMessage = 'Bluetooth scan permissions not granted';
      notifyListeners();
      return;
    }
    
    try {
      isScanning = true;
      scanResults.clear();
      statusMessage = 'scanningForDevices'; // Key for localization
      notifyListeners();
      
      // Start scanning
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
      
      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        scanResults = results;
        print('Scan results updated: ${results.length} devices found');
        
        // Log all devices
        for (var result in results) {
          print('Found device: ${result.device.name} (${result.device.id})');
        }
        
        // Log supported devices count only
        List<ScanResult> supportedDevices = supportedScanResults;
        if (supportedDevices.isNotEmpty) {
          print('Found ${supportedDevices.length} supported device(s)');
        }
        
        notifyListeners();
      });
      
      await Future.delayed(Duration(seconds: 10));
      await stopScan();
      
      // Show scan results
      List<ScanResult> supportedDevices = supportedScanResults;
      if (supportedDevices.isNotEmpty) {
        statusMessage = 'foundSupportedDevices:${supportedDevices.length}'; // Key with count for localization
      } else {
        statusMessage = 'No supported devices found. Make sure ESP32 is powered on and nearby.';
      }
      notifyListeners();
    } catch (e) {
      statusMessage = 'Scan error: $e';
      notifyListeners();
    }
  }

  Future<bool> _checkScanPermissions() async {
    return await Permission.bluetooth.isGranted &&
           await Permission.bluetoothScan.isGranted &&
           await Permission.location.isGranted;
  }
  
  // Filter scan results to show only supported devices
  List<ScanResult> get supportedScanResults {
    return scanResults.where((result) {
      // Primary method: Check for our Service UUID
      if (result.advertisementData.serviceUuids.contains(evilCrowServiceUuid)) {
        return true;
      }
      
      // Secondary method: Check Manufacturer Data
      var manufacturerData = result.advertisementData.manufacturerData;
      if (manufacturerData != null && manufacturerData.containsKey(evilCrowManufacturerId)) {
        var data = manufacturerData[evilCrowManufacturerId];
        if (data != null && data.length >= evilCrowDeviceId.length) {
          bool deviceIdMatch = true;
          for (int i = 0; i < evilCrowDeviceId.length; i++) {
            if (data[i] != evilCrowDeviceId[i]) {
              deviceIdMatch = false;
              break;
            }
          }
          if (deviceIdMatch) {
            return true;
          }
        }
      }
      
      // Fallback method: Check device name
      String deviceName = result.device.name;
      bool nameMatch = supportedDeviceNames.any((supportedName) => 
        deviceName.toLowerCase().contains(supportedName.toLowerCase()));
      
      return nameMatch;
    }).toList();
  }

  Future<void> stopScan() async {
    if (!isScanning) return;
    
    try {
      await FlutterBluePlus.stopScan();
      isScanning = false;
      statusMessage = 'Scan stopped';
      notifyListeners();
    } catch (e) {
      statusMessage = 'Stop scan error: $e';
      notifyListeners();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      statusMessage = 'connecting'; // Key for localization
      _log('info', 'Attempting to connect to device', details: 'Device: ${device.name} (${device.id})');
      print('Connecting to device: ${device.name} (${device.id})');
      notifyListeners();
      
      await device.connect(timeout: Duration(seconds: 10));
      connectedDevice = device;
      
      // Set up connection state monitoring
      device.connectionState.listen((state) {
        bool isConnected = state == BluetoothConnectionState.connected;
        print('Connection state changed: $isConnected');
        if (!isConnected) {
          print('Device disconnected, resetting state');
          _resetConnectionState();
        }
      });
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find our service
      BluetoothService? targetService;
      print('Discovered services:');
      for (BluetoothService service in services) {
        print('  Service UUID: ${service.uuid.toString()}');
        if (service.uuid.toString().toUpperCase() == serviceUuid.toUpperCase()) {
          targetService = service;
          print('  Found target service!');
          break;
        }
      }
      
      if (targetService != null) {
        // Find characteristics
        print('Target service characteristics:');
        for (BluetoothCharacteristic characteristic in targetService.characteristics) {
          print('  Characteristic UUID: ${characteristic.uuid.toString()}');
          if (characteristic.uuid.toString().toUpperCase() == txUuid.toUpperCase()) {
            txCharacteristic = characteristic;
            print('  Found TX characteristic!');
          } else if (characteristic.uuid.toString().toUpperCase() == rxUuid.toUpperCase()) {
            rxCharacteristic = characteristic;
            print('  Found RX characteristic!');
          }
        }
        
        if (txCharacteristic != null && rxCharacteristic != null) {
          isConnected = true;
          statusMessage = 'Connected to ${device.name}';
          _log('info', 'Successfully connected to device', details: 'Device: ${device.name} (${device.id})');
          
          // Save this device for future quick connections
          await saveKnownDevice(device.id.toString());
          
         // Listen to notifications on RX characteristic
         await rxCharacteristic!.setNotifyValue(true);
         
         // Request MTU increase for better performance
         try {
           int mtu = await device.requestMtu(512);
           print('MTU negotiated: $mtu');
           _log('info', 'MTU negotiated', details: 'MTU: $mtu');
         } catch (e) {
           print('MTU negotiation failed: $e');
           _log('warning', 'MTU negotiation failed', details: 'Error: $e');
         }
         
         rxCharacteristic!.onValueReceived.listen((value) {
            _log('debug', 'Received data', details: 'Length: ${value.length} bytes');
            
            // Check if we're hitting MTU limits
            if (value.length >= 20) { // Close to typical BLE MTU
              // Large packet received - this is normal for chunked responses
            }
            
            try {
              // Try to parse as firmware protocol response
              Map<String, dynamic> response = FirmwareBinaryProtocol.parseResponse(Uint8List.fromList(value));
              _log('debug', 'Parsed response', details: response.toString());
              
              // Handle the parsed response
              _handleFirmwareResponse(response);
            } catch (e) {
              // Check if this might be chunked data by looking for magic byte
              if (value.isNotEmpty && value[0] == 0xAA) {
                print('Detected enhanced protocol chunk, attempting chunked parsing...');
                _handleChunkedData(value);
            } else {
                // Fallback to text processing
            String message = String.fromCharCodes(value);
                print('Received text: $message');
                _log('debug', 'Received text', details: message);
                // Old message handling removed - using firmware protocol now
              }
            }
          });
          
          // Send initialization command to get device state
          await Future.delayed(const Duration(milliseconds: 500));
          await sendGetStateCommand();
          
          // Send current time to ESP32 for synchronization
          await Future.delayed(const Duration(milliseconds: 200));
          await sendSetTimeCommand();
          
        } else {
          statusMessage = 'Required characteristics not found';
          await disconnect();
        }
      } else {
        statusMessage = 'Required service not found';
        print('ERROR: Our custom service not found!');
        print('Expected service: $serviceUuid');
        print('Available services:');
        for (BluetoothService service in services) {
          print('  - ${service.uuid.toString()}');
        }
        await disconnect();
      }
      
      notifyListeners();
    } catch (e) {
      statusMessage = 'Connection error: $e';
      notifyListeners();
    }
  }

  void _resetConnectionState() {
    connectedDevice = null;
    txCharacteristic = null;
    rxCharacteristic = null;
    isConnected = false;
    statusMessage = 'disconnected'; // Key for localization
    lastCommandMessage = '';
    fileList.clear();
    currentPath = '/';
    _isWriting = false;
    _isCommandInProgress = false;
    _commandTimeout?.cancel();
    _commandTimeout = null;
    recordedRuntimeFiles.clear();
    detectedSignals.clear();
    
    // Reset recording and frequency searching state for all modules
    isRecording.clear();
    isRecording[0] = false;
    isRecording[1] = false;
    
    isFrequencySearching.clear();
    isFrequencySearching[0] = false;
    isFrequencySearching[1] = false;
    
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (connectedDevice != null) {
      try {
        _log('info', 'Disconnecting from device', details: 'Device: ${connectedDevice!.name}');
        await connectedDevice!.disconnect();
      } catch (e) {
        print('Disconnect error: $e');
        _log('error', 'Error during disconnect', details: 'Error: $e');
      }
    }
    
    // Reset all connection state
    _resetConnectionState();
    _log('info', 'Disconnected from device');
    isLoadingFiles = false;
    
    // Очищаем кеш при отключении
    _fileCache.clear();
    _cacheTimestamps.clear();
    
    // Old chunk buffer clearing removed - using firmware protocol now
    
    // Сбрасываем состояние команд
    _isCommandInProgress = false;
    _lastCommandTime = null;
    
    // Отменяем таймаут команды
    _cancelCommandTimeout();
    
    // Очищаем буферы чанков
    _clearChunkBuffers();
    
    // Очищаем очередь команд
    _commandQueue.clear();
    _isProcessingQueue = false;
    
    notifyListeners();
  }
  
  // Clear known device (useful for troubleshooting)
  Future<void> clearKnownDevice() async {
    await _clearKnownDevice();
    statusMessage = 'Known device cleared. Next connection will scan for devices.';
    notifyListeners();
  }

  Future<void> sendCommand(String command) async {
    if (!isConnected || txCharacteristic == null) {
      statusMessage = 'Not connected';
      _log('error', 'Failed to send command: Not connected', details: 'Command: $command');
      notifyListeners();
      return;
    }
    
    // Add command to queue
    _commandQueue.add(command);
    print('Command queued: $command (queue length: ${_commandQueue.length})');
    
    // Process queue if not already processing
    if (!_isProcessingQueue) {
      _processCommandQueue();
    }
  }
  
  Future<void> _processCommandQueue() async {
    if (_isProcessingQueue || _commandQueue.isEmpty) {
      return;
    }
    
    _isProcessingQueue = true;
    
    while (_commandQueue.isNotEmpty) {
      String command = _commandQueue.removeAt(0);
      print('Processing command from queue: $command');
      
      try {
        await _sendCommandDirect(command);
        
        // Wait between commands to prevent BLE conflicts
        if (_commandQueue.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        print('Command failed: $command, error: $e');
        // Continue with next command even if one fails
      }
    }
    
    _isProcessingQueue = false;
  }
  
  Future<void> _sendCommandDirect(String command) async {
    // Wait for any ongoing write operation to complete
    while (_isWriting) {
      print('Waiting for previous BLE write to complete...');
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Проверяем таймаут между командами
    if (_lastCommandTime != null) {
      final timeSinceLastCommand = DateTime.now().difference(_lastCommandTime!);
      if (timeSinceLastCommand < _commandCooldown) {
        final remainingTime = _commandCooldown - timeSinceLastCommand;
        print('Command cooldown active, waiting: $command (${remainingTime.inMilliseconds}ms remaining)');
        await Future.delayed(remainingTime);
      }
    }
    
    _lastCommandTime = DateTime.now();
    
    print('Sending command: "$command" (length: ${command.length})');
    _log('command', 'Sent command: $command');
    
    try {
      _isWriting = true; // Set write flag
      
      // Convert command to firmware protocol
      Uint8List commandBytes = _convertCommandToFirmwareProtocol(command);
      print('Command bytes length: ${commandBytes.length}');
      print('Command bytes: ${commandBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // Add timeout to BLE write
      await txCharacteristic!.write(commandBytes).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('BLE write timeout after 10 seconds');
        },
      );
      print('BLE write completed successfully');
      
      lastCommandMessage = 'Command sent: $command';
      // Не обновляем statusMessage для команд, чтобы не мешать сообщениям о подключении
      notifyListeners();
      
      // Запускаем таймаут для команд, которые ожидают ответ
      if (_shouldWaitForResponse(command)) {
        _startCommandTimeout(command);
      }
    } catch (e) {
      print('BLE write failed: $e');
      statusMessage = 'Send error: $e';
      _log('error', 'Failed to send command', details: 'Command: $command, Error: $e');
      notifyListeners();
      rethrow; // Re-throw to be caught by queue processor
    } finally {
      _isWriting = false; // Always reset write flag
    }
  }

  // Проверяет, должна ли команда ожидать ответ
  bool _shouldWaitForResponse(String command) {
    // Команды, которые ожидают ответ
    return command.startsWith('sd.list') || 
           command.startsWith('sd.info') ||
           command.startsWith('sd.read');
  }

  // Запускает таймаут для команды
  void _startCommandTimeout(String command) {
    _commandTimeout?.cancel();
    
    // Увеличиваем таймаут для команд списка файлов
    final timeoutDuration = command.startsWith('sd.list') 
        ? const Duration(seconds: 20) 
        : _commandTimeoutDuration;
    
    _commandTimeout = Timer(timeoutDuration, () {
      print('Command timeout: $command');
      _log('warning', 'Command timeout - no response received', details: 'Command: $command');
      
      // Сбрасываем состояние загрузки файлов
      if (isLoadingFiles) {
        isLoadingFiles = false;
        statusMessage = 'Command timeout - please try again';
        notifyListeners();
      }
    });
  }

  // Отменяет таймаут команды (вызывается при получении ответа)
  void _cancelCommandTimeout() {
    _commandTimeout?.cancel();
    _commandTimeout = null;
  }

  // Old binary packet processing removed - using firmware protocol now
  
  
  // Old binary data processing removed - using firmware protocol now
  
  // Old binary packet handling methods removed - using firmware protocol now
  // Old binary packet handling methods removed - using firmware protocol now
  
  
  




  // Old chunk data handling removed - using firmware protocol now
  
  // Old chunk timeout and assembly methods removed - using firmware protocol now

  // Old chunk end handling removed - using firmware protocol now
  
  // Old raw chunk data handling removed - using firmware protocol now

  // Old complete chunked data processing removed - using firmware protocol now

  // Old chunk cleanup removed - using firmware protocol now

  Future<void> refreshFileList({bool forceRefresh = false, int? pathType}) async {
    if (!isConnected) return;
    
    // Немедленно блокируем повторные нажатия
    if (isLoadingFiles) return;
    
    // Use currentPathType if pathType not specified
    int effectivePathType = pathType ?? currentPathType;
    
    // Проверяем кеш, если не принудительное обновление
    if (!forceRefresh && _fileCache.containsKey(currentPath)) {
      fileList = List.from(_fileCache[currentPath]!);
      notifyListeners();
      return;
    }
    
    isLoadingFiles = true;
    notifyListeners();
    
    // Clear chunk buffers before new request
    _clearChunkBuffers();
    
    // Cancel previous timeout if exists
    _fileListTimeout?.cancel();
    
    // Set timeout for file list loading
    _fileListTimeout = Timer(_fileListTimeoutDuration, () {
      if (isLoadingFiles) {
        print('File list loading timeout');
        _log('warning', 'File list loading timeout', details: 'Path: $currentPath, PathType: $effectivePathType');
        isLoadingFiles = false;
        fileListProgress = 0.0;
        statusMessage = 'File list loading timeout - please try again';
        notifyListeners();
      }
    });
    
    // Use binary command with pathType (no need to escape quotes for binary protocol)
    print('refreshFileList: currentPath="$currentPath", pathType=$effectivePathType');
    final command = FirmwareBinaryProtocol.createGetFilesListCommand(currentPath, pathType: effectivePathType);
    await sendBinaryCommand(command);
  }

  Future<void> navigateToDirectory(String directoryName) async {
    if (!isConnected) return;
    
    // Немедленно блокируем повторные нажатия
    if (isLoadingFiles) return;
    
    print('Navigating to directory: "$directoryName"');
    print('Current path before navigation: "$currentPath"');
    
    // Обновляем текущий путь
    if (currentPath.endsWith('/')) {
      currentPath += directoryName;
    } else {
      currentPath += '/$directoryName';
    }
    
    // Убеждаемся что путь начинается с /
    if (!currentPath.startsWith('/')) {
      currentPath = '/$currentPath';
    }
    
    print('New current path: "$currentPath"');
    
    // Проверяем кеш перед загрузкой
    if (_fileCache.containsKey(currentPath)) {
      fileList = List.from(_fileCache[currentPath]!);
      notifyListeners();
      return;
    }
    
    isLoadingFiles = true;
    notifyListeners();
    
    // Clear chunk buffers before new request
    _clearChunkBuffers();
    
    // Cancel previous timeout if exists
    _fileListTimeout?.cancel();
    
    // Set timeout for file list loading
    _fileListTimeout = Timer(_fileListTimeoutDuration, () {
      if (isLoadingFiles) {
        print('File list loading timeout in navigateToDirectory');
        _log('warning', 'File list loading timeout', details: 'Path: $currentPath');
        isLoadingFiles = false;
        fileListProgress = 0.0;
        statusMessage = 'File list loading timeout - please try again';
        notifyListeners();
      }
    });
    
    // Use binary command with pathType (no need to escape quotes for binary protocol)
    final command = FirmwareBinaryProtocol.createGetFilesListCommand(currentPath, pathType: currentPathType);
    await sendBinaryCommand(command);
  }

  Future<void> navigateUp() async {
    if (!isConnected) return;
    
    // Немедленно блокируем повторные нажатия
    if (isLoadingFiles) return;
    
    if (currentPath == '/' || currentPath.isEmpty) {
      return; // Уже в корне
    }
    
    // Убираем последний сегмент пути
    int lastSlash = currentPath.lastIndexOf('/');
    if (lastSlash > 0) {
      currentPath = currentPath.substring(0, lastSlash);
    } else {
      currentPath = '/';
    }
    
    // Проверяем кеш перед загрузкой
    if (_fileCache.containsKey(currentPath)) {
      fileList = List.from(_fileCache[currentPath]!);
      notifyListeners();
      return;
    }
    
    isLoadingFiles = true;
    notifyListeners();
    
    // Clear chunk buffers before new request
    _clearChunkBuffers();
    
    // Cancel previous timeout if exists
    _fileListTimeout?.cancel();
    
    // Set timeout for file list loading
    _fileListTimeout = Timer(_fileListTimeoutDuration, () {
      if (isLoadingFiles) {
        print('File list loading timeout in navigateUp');
        _log('warning', 'File list loading timeout', details: 'Path: $currentPath');
        isLoadingFiles = false;
        fileListProgress = 0.0;
        statusMessage = 'File list loading timeout - please try again';
        notifyListeners();
      }
    });
    
    // Use binary command with pathType (no need to escape quotes for binary protocol)
    final command = FirmwareBinaryProtocol.createGetFilesListCommand(currentPath, pathType: currentPathType);
    await sendBinaryCommand(command);
  }

  /// Switch to a different path type (directory)
  Future<void> switchPathType(int pathType) async {
    if (pathType < 0 || pathType > 3) {
      _log('error', 'Invalid pathType', details: 'pathType must be 0-3, got $pathType');
      return;
    }
    
    currentPathType = pathType;
    currentPath = '/'; // Reset to root of the selected directory
    
    // Clear cache for old path
    _fileCache.clear();
    _cacheTimestamps.clear();
    
    // Refresh file list for new path type
    await refreshFileList(forceRefresh: true);
  }

  /// Clear file cache
  void clearFileCache() {
    _fileCache.clear();
    _cacheTimestamps.clear();
    _log('info', 'File cache cleared');
    notifyListeners();
  }

  /// Invalidate cache for a specific path
  void invalidateCacheForPath(String path) {
    if (_fileCache.containsKey(path)) {
      _fileCache.remove(path);
      _cacheTimestamps.remove(path);
      _log('info', 'Cache invalidated for path: $path');
    }
  }

  /// Get directory path from full file path
  String _getDirectoryPath(String filePath) {
    if (filePath.isEmpty || filePath == '/') {
      return '/';
    }
    // Remove leading slash if present
    String normalizedPath = filePath.startsWith('/') ? filePath.substring(1) : filePath;
    // Find last slash
    int lastSlashIndex = normalizedPath.lastIndexOf('/');
    if (lastSlashIndex == -1) {
      return '/';
    }
    // Return directory path with leading slash
    return '/${normalizedPath.substring(0, lastSlashIndex)}';
  }

  /// Extract relative path from full path (removes base directory like /DATA/RECORDS)
  String _extractRelativePath(String fullPath, int pathType) {
    if (fullPath.isEmpty) return '/';
    
    // Base paths for each pathType
    const basePaths = [
      '/DATA/RECORDS',  // 0
      '/DATA/SIGNALS',  // 1
      '/DATA/PRESETS',  // 2
      '/DATA/TEMP',     // 3
    ];
    
    if (pathType < 0 || pathType >= basePaths.length) {
      return '/';
    }
    
    String basePath = basePaths[pathType];
    
    // Remove base path prefix
    if (fullPath.startsWith(basePath)) {
      String relative = fullPath.substring(basePath.length);
      // If relative is empty or just a slash, it's root
      if (relative.isEmpty || relative == '/') {
        return '/';
      }
      // Ensure it starts with /
      if (!relative.startsWith('/')) {
        relative = '/$relative';
      }
      // Get directory path (remove filename)
      return _getDirectoryPath(relative);
    }
    
    // If base path not found, try to extract relative path anyway
    return _getDirectoryPath(fullPath);
  }

  /// Reset file loading state (useful for recovery from hang)
  void resetFileLoadingState() {
    _fileListTimeout?.cancel();
    _fileListTimeout = null;
    isLoadingFiles = false;
    fileListProgress = 0.0;
    _clearChunkBuffers();
    _log('info', 'File loading state reset');
    notifyListeners();
  }

  // Геттер для прогресса загрузки чанков (old variables removed)
  double get chunkProgress {
    return 0.0; // Old chunk progress removed
  }
  
  // Проверка, идет ли загрузка чанков (old variables removed)
  bool get isChunking {
    return false; // Old chunking removed
  }
  
  // Геттер для общего количества файлов в директории
  int get totalFilesInDirectory => _streamingTotalFiles;
  
  // Геттер для сохраненного устройства
  String? get savedDeviceId => _knownDeviceId;
  String get savedDeviceName => _knownDeviceId != null ? 'EvilCrow_RF2' : '';

  // Методы для работы с файлами
  
  /// Читает содержимое файла с ESP
  Future<String> readFileContent(String filePath, {String? basePath}) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }
    
    // Determine pathType based on basePath
    int pathType = 0;  // Default to /DATA/RECORDS
    String relativePath = filePath;
    
    if (basePath == '/DATA/SIGNALS') {
      pathType = 1;
    } else if (basePath == '/DATA/PRESETS') {
      pathType = 2;
    } else if (basePath == '/DATA/TEMP') {
      pathType = 3;
    }
    
    // Remove /DATA/ prefix if present (shouldn't be, but handle it)
    if (relativePath.startsWith('/DATA/')) {
      relativePath = relativePath.substring(6); // Remove '/DATA/'
    }
    
    // Remove leading slash if present
    if (relativePath.startsWith('/')) {
      relativePath = relativePath.substring(1);
    }
    
    _log('INFO', 'Reading file content: $relativePath (pathType: $pathType, basePath: $basePath)');
    
    // Устанавливаем флаг загрузки
    isLoadingFileContent = true;
    fileContentProgress = 0.0;
    notifyListeners();
    
    // Очищаем предыдущее состояние
    _currentFileContent = null;
    _pendingFileReadCompleter?.completeError('New file read started');
    _pendingFileReadCompleter = Completer<String>();
    
    // Use binary command with path type - pass full relative path including subdirectory
    final command = FirmwareBinaryProtocol.createLoadFileDataCommand(relativePath, pathType: pathType);
    _log('INFO', 'Sending binary command for file: $relativePath (pathType: $pathType, command length: ${command.length})');
    
    // Отправляем бинарную команду чтения файла
    await sendBinaryCommand(command);
    
    // Устанавливаем таймаут
    Timer timeout = Timer(const Duration(seconds: 60), () {
      if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
        _log('ERROR', 'Timeout reading file: $filePath');
        _pendingFileReadCompleter!.completeError('Timeout reading file');
        _pendingFileReadCompleter = null;
        isLoadingFileContent = false;
        fileContentProgress = 0.0;
        notifyListeners();
      }
    });
    
    try {
      final result = await _pendingFileReadCompleter!.future;
      return result;
    } finally {
      timeout.cancel();
      _pendingFileReadCompleter = null;
      _currentFileContent = null;
      isLoadingFileContent = false;
      fileContentProgress = 0.0;
      notifyListeners();
    }
  }
  
  /// Загружает файл с ESP с прогрессом (использует бинарный протокол)
  Future<String?> downloadFile(
    String filePath, {
    Function(double progress)? onProgress,
  }) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }
    
    _log('INFO', 'Downloading file: $filePath');
    
    // Используем readFileContent, который уже использует бинарный протокол
    // Определяем pathType на основе текущего пути
    try {
      final basePath = _getBasePathForPathType(currentPathType);
      final content = await readFileContent(filePath, basePath: basePath);
      
      // Вызываем callback прогресса если есть
      onProgress?.call(1.0);
      
      return content;
    } catch (e) {
      _log('ERROR', 'Error downloading file: $e');
      rethrow;
    }
  }
  
  /// Получает базовый путь для pathType
  String? _getBasePathForPathType(int pathType) {
    switch (pathType) {
      case 0:
        return '/DATA/RECORDS';
      case 1:
        return '/DATA/SIGNALS';
      case 2:
        return '/DATA/PRESETS';
      case 3:
        return '/DATA/TEMP';
      default:
        return '/DATA/RECORDS';
    }
  }
  
  /// Очищает буферы чанков
  /// [clearStreamingBuffer] - если true, также очищает streaming буферы (по умолчанию true)
  void _clearChunkBuffers({bool clearStreamingBuffer = true}) {
    _chunkData.clear();
    _expectedChunks.clear();
    _receivedChunks.clear();
    _chunkStartTimes.clear();
    _chunkLastReceived.clear();
    // Clear streaming file list buffer only if explicitly requested
    // Don't clear during active streaming to prevent data loss
    if (clearStreamingBuffer) {
      _streamingFileBuffer.clear();
      _isStreamingFileList = false;
      _streamingTotalFiles = 0;
    }
  }
  
  /// Очищает устаревшие буферы чанков (старше _chunkTimeout или если чанки не приходят)
  /// НЕ очищает streaming буферы - они управляются отдельно
  void _cleanupStaleChunkBuffers() {
    final now = DateTime.now();
    final staleChunkIds = <int>[];
    
    for (var chunkId in _chunkStartTimes.keys) {
      final startTime = _chunkStartTimes[chunkId]!;
      final age = now.difference(startTime);
      
      // Check if buffer is too old (overall timeout)
      if (age > _chunkTimeout) {
        staleChunkIds.add(chunkId);
        continue;
      }
      
      // Check if chunks haven't been received recently (stale after initial creation)
      if (_chunkLastReceived.containsKey(chunkId)) {
        final lastReceived = _chunkLastReceived[chunkId]!;
        final timeSinceLastChunk = now.difference(lastReceived);
        
        // If no chunks received for a while, consider stale
        if (timeSinceLastChunk > _chunkStaleTimeout) {
          final received = _receivedChunks[chunkId] ?? <int>{};
          final expected = _expectedChunks[chunkId] ?? 0;
          
          // Only mark as stale if we're missing chunks (not just waiting)
          if (received.length < expected) {
            staleChunkIds.add(chunkId);
          }
        }
      }
    }
    
    if (staleChunkIds.isNotEmpty) {
      print('Cleaning up ${staleChunkIds.length} stale chunk buffers: $staleChunkIds');
      for (var chunkId in staleChunkIds) {
        _chunkData.remove(chunkId);
        _expectedChunks.remove(chunkId);
        _receivedChunks.remove(chunkId);
        _chunkStartTimes.remove(chunkId);
        _chunkLastReceived.remove(chunkId);
      }
    }
  }
  
  // Callback функции для чанков (будут установлены временно)
  Function(int sessionId, String data)? _onChunkComplete;
  Function(int sessionId, double progress)? _onChunkProgress;
  
  // Chunked response handling for firmware protocol
  final Map<int, Map<int, Uint8List>> _chunkData = {}; // chunkId -> chunkNumber -> data (allows overwriting duplicates)
  final Map<int, int> _expectedChunks = {}; // chunkId -> total chunks expected
  final Map<int, Set<int>> _receivedChunks = {}; // chunkId -> set of received chunk numbers
  final Map<int, DateTime> _chunkStartTimes = {}; // chunkId -> timestamp when chunk buffer was created
  final Map<int, DateTime> _chunkLastReceived = {}; // chunkId -> timestamp when last chunk was received
  static const Duration _chunkTimeout = Duration(seconds: 3); // Timeout for stale chunk buffers
  static const Duration _chunkStaleTimeout = Duration(milliseconds: 500); // Timeout if chunks arrive out of order
  
  // Command queue to prevent BLE write conflicts
  final List<String> _commandQueue = [];
  bool _isProcessingQueue = false;
  
  // Callback для JSON ответов
  Function(dynamic jsonData)? _onJsonReceived;

  /// Convert text command to firmware binary protocol
  Uint8List _convertCommandToFirmwareProtocol(String command) {
    print('Converting command to enhanced protocol: "$command"');
    
    // Parse command and convert to appropriate firmware protocol
    if (command == 'getState') {
      return FirmwareBinaryProtocol.createGetStateCommand();
    } else if (command.startsWith('scan')) {
      // Parse scan command: "scan <minRssi> <module>"
      List<String> parts = command.split(' ');
      if (parts.length >= 3) {
        int minRssi = int.tryParse(parts[1]) ?? -100;
        int module = int.tryParse(parts[2]) ?? 0;
        return FirmwareBinaryProtocol.createRequestScanCommand(minRssi, module);
      }
      return FirmwareBinaryProtocol.createRequestScanCommand(-100, 0);
    } else if (command.startsWith('idle')) {
      // Parse idle command: "idle <module>"
      List<String> parts = command.split(' ');
      if (parts.length >= 2) {
        int module = int.tryParse(parts[1]) ?? 0;
        return FirmwareBinaryProtocol.createRequestIdleCommand(module);
      }
      return FirmwareBinaryProtocol.createRequestIdleCommand(0);
    } else if (command.startsWith('sd.list')) {
      // Parse list command: "sd.list <path>" or "sd.list "<path>""
      String path = command.substring(7).trim();
      
      // Убираем кавычки если они есть
      if (path.startsWith('"') && path.endsWith('"')) {
        path = path.substring(1, path.length - 1);
      }
      
      if (path.isEmpty || path == '/') path = ''; // Don't send '/' prefix
      print('Creating getFilesList command for path: "$path" with pathType: $currentPathType');
      // Use currentPathType instead of hardcoded 0 - ensures all storage types work correctly
      return FirmwareBinaryProtocol.createGetFilesListCommand(path, pathType: currentPathType);
    } else if (command.startsWith('sd.read')) {
      // Parse read command: "sd.read <path>"
      String path = command.substring(7).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createLoadFileDataCommand(path);
    } else if (command.startsWith('sd.mkdir')) {
      // Parse mkdir command: "sd.mkdir <path>"
      String path = command.substring(8).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createCreateDirectoryCommand(path);
    } else if (command.startsWith('sd.rm')) {
      // Parse remove command: "sd.rm <path>"
      String path = command.substring(6).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createRemoveFileCommand(path);
    } else if (command.startsWith('sd.mv')) {
      // Parse move command: "sd.mv <from> <to>"
      List<String> parts = command.split(' ');
      if (parts.length >= 3) {
        String fromPath = parts[1];
        String toPath = parts[2];
        if (fromPath.startsWith('/')) fromPath = fromPath.substring(1); // Remove leading '/'
        if (toPath.startsWith('/')) toPath = toPath.substring(1); // Remove leading '/'
        return FirmwareBinaryProtocol.createRenameFileCommand(fromPath, toPath);
      }
    } else if (command.startsWith('tx.file')) {
      // Parse transmit from file command: "tx.file <path>"
      String path = command.substring(7).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createTransmitFromFileCommand(path);
    } else if (command.startsWith('tx.bin')) {
      // Parse transmit binary command: "tx.bin <frequency> <pulseDuration> <data>"
      List<String> parts = command.split(' ');
      if (parts.length >= 4) {
        double frequency = double.tryParse(parts[1]) ?? 433.92;
        int pulseDuration = int.tryParse(parts[2]) ?? 100;
        String data = parts.sublist(3).join(' ');
        return FirmwareBinaryProtocol.createTransmitBinaryCommand(frequency, pulseDuration, data);
      }
    }
    
    // Default: send as getState command
    print('Unknown command, defaulting to getState');
    return FirmwareBinaryProtocol.createGetStateCommand();
  }

  /// Handle firmware protocol responses
  void _handleFirmwareResponse(Map<String, dynamic> response) {
    int packetType = response['packetType'] ?? 0;
    int chunkId = response['chunkId'] ?? 0;
    int chunkNumber = response['chunkNumber'] ?? 0;
    int totalChunks = response['totalChunks'] ?? 1;
    bool isChunked = response['isChunked'] ?? false;
    bool isLastChunk = response['isLastChunk'] ?? false;
    bool isBinary = response['isBinary'] ?? false;
    Uint8List? payloadBytes = response['payloadBytes'];
    String payloadString = response['payload'] ?? '';
    
    _log('debug', 'Handling firmware response', details: 'PacketType: $packetType, Chunked: $isChunked, totalChunks: $totalChunks, Binary: $isBinary');
    
    // CRITICAL: Always check totalChunks > 1, not just isChunked flag
    // This ensures chunked messages are never processed as single messages
    if (totalChunks > 1) {
      print('Processing as chunked: chunkId=$chunkId, chunkNumber=$chunkNumber, totalChunks=$totalChunks, isLastChunk=$isLastChunk');
      _handleChunkedResponse(chunkId, chunkNumber, totalChunks, isLastChunk, isBinary, payloadBytes, payloadString);
    } else {
      // Single packet - handle directly
      // Check if this is a system message that should be processed even with active chunk buffers
      bool isSystemMessage = false;
      bool isFileListMessage = false;
      
      if (isBinary && payloadBytes != null && payloadBytes.isNotEmpty) {
        // Binary system messages: Heartbeat is 0x82, Status is 0x81, FileList is 0xA1
        int messageType = payloadBytes[0];
        isSystemMessage = (messageType == 0x82 || messageType == 0x81);
        isFileListMessage = (messageType == 0xA1);
      } else if (!isBinary && payloadString.isNotEmpty) {
        // JSON system messages: Check if it's a system notification (SignalRecorded, SignalDetected, etc.)
        // These should be processed even with active chunk buffers
        try {
          // Quick check without full parsing to avoid overhead
          if (payloadString.contains('"type":"SignalRecorded"') ||
              payloadString.contains('"type":"SignalDetected"') ||
              payloadString.contains('"type":"SignalRecordError"') ||
              payloadString.contains('"type":"SignalSent"') ||
              payloadString.contains('"type":"SignalSendingError"') ||
              payloadString.contains('"type":"ModeSwitch"') ||
              payloadString.contains('"type":"State"') ||
              payloadString.contains('"action":"list"')) {
            isSystemMessage = true;
            if (payloadString.contains('"action":"list"')) {
              isFileListMessage = true;
            }
          }
        } catch (e) {
          // If check fails, continue with normal processing
        }
      }
      
      // Additional safety: check if we have active chunk buffers (shouldn't happen for single packet)
      // Exception: system messages and file list messages should be processed even with active chunk buffers
      // File list messages can arrive as separate single packets during streaming
      if (_chunkData.isNotEmpty && !isSystemMessage && !isFileListMessage) {
        // Clean up stale chunk buffers first - they might be blocking new messages
        _cleanupStaleChunkBuffers();
        
        // Double-check: if buffers exist but are very old (>300ms), they're probably stuck
        // Also clean ALL buffers missing chunk 1 (chunk 1 is required for completion)
        final now = DateTime.now();
        final stuckBuffers = <int>[];
        for (var chunkId in _chunkData.keys) {
          bool shouldClean = false;
          
          if (_chunkStartTimes.containsKey(chunkId)) {
            final age = now.difference(_chunkStartTimes[chunkId]!);
            // Clean if buffer is old
            if (age > const Duration(milliseconds: 300)) {
              shouldClean = true;
            }
          }
          
          // CRITICAL: Always clean buffers missing chunk 1 (required for multi-chunk messages)
          // If chunk 1 is missing, the message can never be completed
          if (!shouldClean && _receivedChunks.containsKey(chunkId)) {
            if (!_receivedChunks[chunkId]!.contains(1)) {
              final expected = _expectedChunks[chunkId] ?? 0;
              if (expected > 1) { // Only for multi-chunk messages
                // Clean immediately - chunk 1 is required and if it hasn't arrived yet,
                // it's likely lost (especially if we're receiving other messages)
                shouldClean = true;
              }
            }
          }
          
          if (shouldClean) {
            stuckBuffers.add(chunkId);
          }
        }
        
        if (stuckBuffers.isNotEmpty) {
          print('Cleaning up ${stuckBuffers.length} stuck chunk buffers (old or missing chunk 1): $stuckBuffers');
          for (var chunkId in stuckBuffers) {
            _chunkData.remove(chunkId);
            _expectedChunks.remove(chunkId);
            _receivedChunks.remove(chunkId);
            _chunkStartTimes.remove(chunkId);
            _chunkLastReceived.remove(chunkId);
          }
        }
        
        // If buffers are still active after aggressive cleanup, ignore this single packet
        // Exception: file list messages should be processed even with active chunk buffers
        // because they arrive as separate single packets during streaming
        if (_chunkData.isNotEmpty && !isFileListMessage) {
          print('WARNING: Received single packet (totalChunks=1) but chunk buffers are active (${_chunkData.keys.toList()}), ignoring to avoid processing incomplete data');
          return;
        }
      }
      
      if (isBinary && payloadBytes != null) {
        _handleBinaryMessage(payloadBytes);
      } else {
        _handleSingleResponse(payloadString);
      }
    }
  }
  
  /// Handle chunked responses from firmware protocol
  void _handleChunkedResponse(int chunkId, int chunkNumber, int totalChunks, bool isLastChunk, bool isBinary, Uint8List? payloadBytes, String payloadString) {
    int payloadLength = isBinary ? (payloadBytes?.length ?? 0) : payloadString.length;
    
    // Clean up stale chunk buffers periodically
    _cleanupStaleChunkBuffers();
    
    // Initialize chunk storage if needed
    final now = DateTime.now();
    if (!_chunkData.containsKey(chunkId)) {
      _chunkData[chunkId] = <int, Uint8List>{};
      _expectedChunks[chunkId] = totalChunks;
      _receivedChunks[chunkId] = <int>{};
      _chunkStartTimes[chunkId] = now;
      _chunkLastReceived[chunkId] = now;
      print('Initialized chunk buffer for chunkId $chunkId, expecting $totalChunks chunks');
    } else {
      // Update last received time
      _chunkLastReceived[chunkId] = now;
    }
    
    // Check if chunk arrives out of order (e.g., chunk 2/2 before chunk 1/2)
    // If we're missing chunk 1 and this is chunk 2+, check if we should wait or cleanup
    if (chunkNumber > 1 && !_receivedChunks[chunkId]!.contains(1)) {
      final bufferAge = now.difference(_chunkStartTimes[chunkId]!);
      // If buffer is older than 100ms and we're missing chunk 1, it's likely lost
      // Reduced from 200ms to be more aggressive - BLE chunks should arrive within 100ms
      if (bufferAge > const Duration(milliseconds: 100)) {
        print('WARNING: Chunk $chunkNumber/$totalChunks arrived for chunkId $chunkId but chunk 1 is missing (buffer age: ${bufferAge.inMilliseconds}ms), cleaning up stale buffer');
        _chunkData.remove(chunkId);
        _expectedChunks.remove(chunkId);
        _receivedChunks.remove(chunkId);
        _chunkStartTimes.remove(chunkId);
        _chunkLastReceived.remove(chunkId);
        // Don't process this chunk - it's incomplete without chunk 1
        return;
      } else {
        print('INFO: Chunk $chunkNumber/$totalChunks arrived for chunkId $chunkId but chunk 1 is not yet received (may arrive out of order, age: ${bufferAge.inMilliseconds}ms)');
      }
    }
    
    // Handle duplicate chunks: overwrite data (safe since data is identical)
    // This handles BLE stack retransmissions gracefully
    bool isDuplicate = _receivedChunks[chunkId]!.contains(chunkNumber);
    
    if (isDuplicate) {
      print('INFO: Duplicate chunk $chunkNumber/$totalChunks for chunkId $chunkId, overwriting (BLE retransmission)');
    } else {
      // Mark chunk as received only if it's new
      _receivedChunks[chunkId]!.add(chunkNumber);
    }
    
    // Store chunk data by chunk number (allows overwriting duplicates)
    Uint8List chunkBytes;
    if (isBinary && payloadBytes != null) {
      chunkBytes = payloadBytes;
    } else {
      chunkBytes = Uint8List.fromList(utf8.encode(payloadString));
    }
    
    // Overwrite if duplicate (safe - data is identical)
    _chunkData[chunkId]![chunkNumber] = chunkBytes;
    
    // Update progress for file list or file content loading
    if (totalChunks > 1) {
      double progress = _receivedChunks[chunkId]!.length / totalChunks;
      if (isLoadingFiles) {
        fileListProgress = progress;
        notifyListeners();
      } else if (isLoadingFileContent) {
        fileContentProgress = progress;
        notifyListeners();
      }
    }
    
    
    // Check if we have all chunks
    if (_receivedChunks[chunkId]!.length == totalChunks) {
      // Rebuild complete message from chunks in order
      BytesBuilder completeBuilder = BytesBuilder();
      for (int i = 1; i <= totalChunks; i++) {
        if (_chunkData[chunkId]!.containsKey(i)) {
          completeBuilder.add(_chunkData[chunkId]![i]!);
        } else {
          print('ERROR: Missing chunk $i/$totalChunks for chunkId $chunkId');
          return; // Don't process incomplete data
        }
      }
      
      // CRITICAL: Clean up chunk storage BEFORE processing to avoid false positives in _handleBinaryMessage
      // Save data and remove from active buffers first
      Uint8List completeBytes = completeBuilder.toBytes();
      _chunkData.remove(chunkId);
      _expectedChunks.remove(chunkId);
      _receivedChunks.remove(chunkId);
      _chunkStartTimes.remove(chunkId);
      _chunkLastReceived.remove(chunkId);
      
      // Process complete chunked response
      // Check if binary message (first byte >= 0x80)
      if (completeBytes.isNotEmpty && completeBytes[0] >= 0x80) {
        _handleBinaryMessage(completeBytes);
      } else {
        // Text message - decode as UTF-8 and parse as JSON
        try {
          String completeData = utf8.decode(completeBytes);
          dynamic jsonData = jsonDecode(completeData);
          _handleCompleteResponse(jsonData);
        } catch (e) {
          String completeData = utf8.decode(completeBytes, allowMalformed: true);
          _handleCompleteResponse(completeData);
        }
      }
    }
  }
  
  /// Handle single (non-chunked) responses
  void _handleSingleResponse(String payload) {
    print('Handling single response: ${payload.substring(0, payload.length > 100 ? 100 : payload.length)}${payload.length > 100 ? '...' : ''}');
    
    // CRITICAL: Check if this might be part of a chunked message first
    // If we have active chunk buffers, check if this is a system message
    if (_chunkData.isNotEmpty) {
      // Check if this is a system notification that should be processed
      bool isSystemNotification = false;
      try {
        if (payload.contains('"type":"SignalRecorded"') ||
            payload.contains('"type":"SignalDetected"') ||
            payload.contains('"type":"SignalRecordError"') ||
            payload.contains('"type":"SignalSent"') ||
            payload.contains('"type":"SignalSendingError"') ||
            payload.contains('"type":"ModeSwitch"') ||
            payload.contains('"type":"State"')) {
          isSystemNotification = true;
        }
      } catch (e) {
        // If check fails, treat as non-system
      }
      
      if (!isSystemNotification) {
        print('WARNING: Received single response while chunk buffers are active, ignoring to avoid processing incomplete data');
        return;
      } else {
        print('INFO: Processing system notification even with active chunk buffers');
      }
    }
    
    // BINARY MESSAGE CHECK: Check if this is a binary message (0x80-0xFF)
    if (payload.isNotEmpty) {
      final firstByte = payload.codeUnitAt(0);
      if (firstByte >= 0x80) {
        print('Detected binary message: 0x${firstByte.toRadixString(16)}');
        _handleBinaryMessage(Uint8List.fromList(payload.codeUnits));
        return;
      }
    }
    
    try {
      // Try to parse as JSON
      dynamic jsonData = jsonDecode(payload);
      _handleCompleteResponse(jsonData);
    } catch (e) {
      // Handle as plain text - check if it looks like JSON
      if (payload.trim().startsWith('{') && payload.trim().endsWith('}')) {
        // Try to extract type manually from plain text
        if (payload.contains('"type":"ModeSwitch"')) {
          try {
            // Try to extract just the data part
            int dataStart = payload.indexOf('"data":');
            if (dataStart != -1) {
              String dataPart = payload.substring(dataStart + 7); // Skip '"data":'
              if (dataPart.startsWith('{')) {
                // Find matching closing brace
                int braceCount = 0;
                int endIndex = -1;
                for (int i = 0; i < dataPart.length; i++) {
                  if (dataPart[i] == '{') braceCount++;
                  if (dataPart[i] == '}') {
                    braceCount--;
                    if (braceCount == 0) {
                      endIndex = i;
                      break;
                    }
                  }
                }
                if (endIndex != -1) {
                  String dataJson = dataPart.substring(0, endIndex + 1);
                  Map<String, dynamic> modeData = jsonDecode(dataJson);
                  _handleModeSwitch(modeData);
                  return;
                }
              }
            }
          } catch (e2) {
            print('Manual parsing failed: $e2');
          }
        }
      }
      // Fallback to plain text handling
      print('Plain text response: $payload');
      _log('info', 'Plain text response received', details: payload);
    }
  }
  
  /// Handle chunked data from enhanced protocol
  void _handleChunkedData(List<int> data) {
    try {
      // Parse the chunk header
      if (data.length < 6) {
        print('Chunk too short: ${data.length} bytes');
        return;
      }
      
      // Format: [Magic:1][Type:1][ChunkID:1][ChunkNum:1][TotalChunks:1][DataLen:2][Data:variable][Checksum:1]
      int magic = data[0];
      int packetType = data[1];
      int chunkId = data[2];
      int chunkNumber = data[3];
      int totalChunks = data[4];
      int dataLength = data[5] | (data[6] << 8);  // Little-endian: 2 bytes
      const int PACKET_HEADER_SIZE = 7;  // Updated header size
      
      // Validate magic byte
      if (magic != 0xAA) {
        print('Invalid magic byte in chunk: 0x${magic.toRadixString(16)}');
        return;
      }
      
      // Extract payload
      // BLE may truncate packets to 509 bytes, so use actual received length
      int actualDataLength = data.length - PACKET_HEADER_SIZE - 1; // -1 for checksum
      
      if (actualDataLength < 0) {
        print('Chunk too short: got ${data.length} bytes, need at least ${PACKET_HEADER_SIZE + 1}');
        return;
      }
      
      // Use actual received length, but warn if it's less than expected
      if (actualDataLength < dataLength) {
        print('WARNING: Chunk truncated by BLE: expected $dataLength bytes, got $actualDataLength');
      }
      
      // Use minimum of expected and actual length to avoid out-of-bounds
      int payloadLength = actualDataLength < dataLength ? actualDataLength : dataLength;
      List<int> payload = data.sublist(PACKET_HEADER_SIZE, PACKET_HEADER_SIZE + payloadLength);
      int checksum = data[PACKET_HEADER_SIZE + payloadLength];
      
      // Calculate checksum using actual payload length
      int calculatedChecksum = 0;
      for (int i = 0; i < PACKET_HEADER_SIZE + payloadLength; i++) {
        calculatedChecksum ^= data[i];
      }
      
      if (checksum != calculatedChecksum) {
        print('Invalid checksum in chunk: received 0x${checksum.toRadixString(16)}, calculated 0x${calculatedChecksum.toRadixString(16)}');
        return;
      }
      
      
      // Old chunk processing removed - using firmware protocol now
      print('Old chunk processing in _handleChunkedData - should use firmware protocol instead');
      
    } catch (e) {
      print('Error handling chunked data: $e');
    }
  }

  /// Handle complete responses (both chunked and single)
  void _handleCompleteResponse(dynamic data) {
    print('_handleCompleteResponse called with data type: ${data.runtimeType}');
    if (data is Map) {
      String type = data['type'] ?? 'unknown';
      print('Processing response type: $type');
      
      switch (type) {
        case 'state':
        case 'State':
          _handleStateResponse(data.cast<String, dynamic>());
          break;
        case 'SignalDetected':
          _handleSignalDetectedResponse(data);
          break;
        case 'SignalRecorded':
          _handleSignalRecordedResponse(data);
          break;
        case 'SignalRecordError':
          _handleSignalRecordErrorResponse(data);
          break;
        case 'SignalSent':
          _handleSignalSentResponse(data);
          break;
        case 'SignalSendingError':
          _handleSignalSendingErrorResponse(data);
          break;
        case 'ModeSwitch':
          _handleModeSwitch(data['data']);
          break;
        case 'FileSystem':
          _handleFileSystemResponse(data);
          break;
        case 'DirectoryTree':
          _handleFileSystemResponse(data); // DirectoryTree also goes through FileSystem handler
          break;
        case 'file_data':
          _handleFileDataResponse(data);
          break;
        case 'FileUpload':
          _handleFileUploadResponse(data);
          break;
        case 'scan_result':
          _handleScanResult(data);
          break;
        case 'files_list':
          _handleFilesListResponse(data);
          break;
        case 'error':
        case 'Error':
          _handleErrorResponse(data);
          break;
        case 'notification':
          _handleNotification(data);
          break;
        default:
          print('Unknown response type: $type');
          _log('warning', 'Unknown response type', details: 'Type: $type, Data: $data');
      }
    } else {
      // Handle plain text responses
      print('Plain text response: $data');
      _log('info', 'Plain text response received', details: data.toString());
    }
  }


  /// Handle scan result
  void _handleScanResult(dynamic data) {
    print('Scan result: $data');
    _log('info', 'Scan result received', details: data.toString());
    // Update scan results in UI
    notifyListeners();
  }

  /// Handle files list response
  void _handleFilesListResponse(dynamic data) {
    print('Files list response: $data');
    _log('info', 'Files list received', details: data.toString());
    
    if (data is List) {
      fileList.clear();
      for (var item in data) {
        if (item is Map) {
          fileList.add(FileItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      notifyListeners();
    }
  }

  /// Handle file data response
  void _handleFileDataResponse(dynamic data) {
    print('File data response: $data');
    _log('info', 'File data received', details: data.toString());
    
    // Handle file content response
    if (data is Map<String, dynamic>) {
      if (data.containsKey('content')) {
        String fileContent = data['content'];
        print('File content received via file_data, length: ${fileContent.length}');
        
        // Store the file content for the current file reading operation
        _currentFileContent = fileContent;
        
        // If we have a pending file reading operation, complete it
        if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
          _pendingFileReadCompleter!.complete(fileContent);
          _pendingFileReadCompleter = null;
        }
      }
    }
    
    notifyListeners();
  }

  /// Handle error response
  void _handleErrorResponse(dynamic data) {
    print('Error response: $data');
    _log('error', 'Error response received', details: data.toString());
    
    // Extract error message
    String errorMessage = 'Unknown error';
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data')) {
        errorMessage = data['data'].toString();
      } else if (data.containsKey('message')) {
        errorMessage = data['message'].toString();
      }
    } else if (data is String) {
      errorMessage = data;
    }
    
    statusMessage = 'Error: $errorMessage';
    notifyListeners();
  }

  /// Handle notification response
  void _handleNotification(dynamic data) {
    print('Notification response: $data');
    _log('info', 'Notification received', details: data.toString());
    // Update UI or state on the basis of notification
    notifyListeners();
  }

  /// Handle signal detected response
  void _handleSignalDetectedResponse(dynamic data) {
    print('Signal detected: $data');
    _log('info', 'Signal detected', details: data.toString());
    
    // Parse the signal data and add to detected signals list
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      Map<String, dynamic> signalData = data['data'];
      print('SignalDetected: Parsing signal data: $signalData');
      
      // Get module number
      int module = int.tryParse(signalData['module']?.toString() ?? '0') ?? 0;
      
      // In binary protocol, isBackgroundScanner is always false (sent as string 'false')
      // Parse it safely - can be bool or String
      bool isBackgroundScanner = false;
      if (signalData['isBackgroundScanner'] != null) {
        final value = signalData['isBackgroundScanner'];
        if (value is bool) {
          isBackgroundScanner = value;
        } else if (value is String) {
          isBackgroundScanner = value.toLowerCase() == 'true';
        }
      }
      
      // Create DetectedSignal from the data first
      DetectedSignal signal = DetectedSignal(
        frequency: signalData['frequency']?.toString() ?? '0',
        modulation: 'Unknown', // SignalDetected doesn't include modulation
        rssi: int.tryParse(signalData['rssi']?.toString() ?? '0') ?? 0,
        data: '', // SignalDetected doesn't include data
        timestamp: DateTime.now(),
        module: module,
        isBackgroundScanner: isBackgroundScanner,
      );
      
      // Note: Frequency search state will be updated by ModeSwitch message
      // when the module transitions back to Idle after detecting signal
      // But add a fallback in case ModeSwitch doesn't arrive
      print('Signal detected for module $module - waiting for ModeSwitch to update state');
      
      // Fallback: if ModeSwitch doesn't arrive within 2 seconds, stop search manually
      if (!signal.isBackgroundScanner && isFrequencySearching[module] == true) {
        Future.delayed(const Duration(seconds: 2), () {
          // Only stop if ModeSwitch hasn't already stopped the search
          if (isFrequencySearching[module] == true) {
            isFrequencySearching[module] = false;
            print('Module $module frequency search stopped (fallback after signal detection)');
            _log('info', 'Frequency search stopped (fallback)', details: 'Module: $module');
            
            // Also update module state in cc1101Modules if it exists
            if (cc1101Modules != null && module < cc1101Modules!.length) {
              cc1101Modules![module]['mode'] = 'Idle';
              print('Updated module $module mode in cc1101Modules to Idle (fallback)');
            } else if (cc1101Modules == null) {
              // Initialize if needed
              cc1101Modules = [];
              while (cc1101Modules!.length <= module) {
                cc1101Modules!.add({
                  'id': cc1101Modules!.length,
                  'mode': 'Unknown',
                });
              }
              cc1101Modules![module]['mode'] = 'Idle';
              cc1101Modules![module]['id'] = module;
              print('Created module $module in cc1101Modules with mode Idle (fallback)');
            }
            
            notifyListeners();
          }
        });
      }
      
      print('SignalDetected: Created signal: $signal');
      
      // Only add to detected signals list if it's NOT a background scanner
      // Background scanner signals should only appear on scanner screen
      if (!signal.isBackgroundScanner) {
      detectedSignals.insert(0, signal);
      
      // Limit list size (max 100 signals)
      if (detectedSignals.length > 100) {
        detectedSignals = detectedSignals.take(100).toList();
      }
      
      // Sort by timestamp (newest first)
      detectedSignals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('Added signal to list. Total signals: ${detectedSignals.length}');
      } else {
        print('Background scanner signal - not adding to main list');
      }
    }
    
    notifyListeners();
  }

  /// Handle signal recorded response
  void _handleSignalRecordedResponse(dynamic data) {
    print('Signal recorded: $data');
    _log('info', 'Signal recorded', details: data.toString());
    
    // Add the new file to recorded files list
    String? filename;
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        // Format: {type: SignalRecorded, data: {filename: ...}}
        filename = data['data']['filename'];
      } else if (data['filename'] != null) {
        // Format: {filename: ...}
        filename = data['filename'];
      }
    }
    
    if (filename != null) {
      final newFile = {
        'filename': filename,
        'date': DateTime.now().toIso8601String(),
        'type': 'recorded'
      };
      
      // Add to the beginning of the list
      recordedRuntimeFiles.insert(0, newFile);
      
      // Limit list size to prevent memory issues
      if (recordedRuntimeFiles.length > 50) {
        recordedRuntimeFiles = recordedRuntimeFiles.take(50).toList();
      }
      
      print('Added new recorded file: $filename');
    } else {
      print('Could not extract filename from SignalRecorded data: $data');
    }
    
    notifyListeners();
  }

  /// Удаляет файл из локального списка записанных файлов
  void removeRecordedFile(String filename) {
    recordedRuntimeFiles.removeWhere((file) => file['filename'] == filename);
    notifyListeners();
  }

  /// Handle signal record error response
  void _handleSignalRecordErrorResponse(dynamic data) {
    print('Signal record error: $data');
    _log('error', 'Signal record error', details: data.toString());
    notifyListeners();
  }

  /// Handle signal sent response
  void _handleSignalSentResponse(dynamic data) {
    print('Signal sent: $data');
    _log('info', 'Signal sent', details: data.toString());
    notifyListeners();
  }

  /// Handle signal sending error response
  void _handleSignalSendingErrorResponse(dynamic data) {
    print('Signal sending error: $data');
    String errorMessage = 'Transmission failed';
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final errorData = data['data'];
      if (errorData is Map<String, dynamic>) {
        errorMessage = errorData['error']?.toString() ?? 'Transmission failed';
        if (errorData.containsKey('filename')) {
          errorMessage += ': ${errorData['filename']}';
        }
      }
    }
    statusMessage = errorMessage;
    _log('error', 'Signal sending error', details: errorMessage);
    notifyListeners();
  }

  /// Handle mode switch response
  void _handleModeSwitchResponse(dynamic data) {
    print('Mode switch: $data');
    _log('info', 'Mode switch', details: data.toString());
    notifyListeners();
  }

  /// Handle file system response
  void _handleFileSystemResponse(dynamic data) {
    print('File system response: $data');
    _log('info', 'File system response', details: data.toString());
    
    // Handle file system operations
    if (data is Map<String, dynamic>) {
      // Handle DirectoryTree response FIRST (top-level type check)
      // Structure from BinaryMessageParser: {type: 'DirectoryTree', data: {pathType: 0, paths: [...], streaming: bool, totalDirs: int}}
      if (data.containsKey('type') && data['type'] == 'DirectoryTree') {
        print('DirectoryTree response detected (top-level): $data');
        
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          Map<String, dynamic> directoryTreeData = data['data'];
          
          // Check for errors first
          if (directoryTreeData.containsKey('error')) {
            print('Directory tree error: ${directoryTreeData['error']}');
            _isStreamingDirectoryTree = false;
            _streamingDirectoryTreeBuffer.clear();
            _streamingTotalDirs = 0;
            
            if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
              _pendingDirectoryTreeCompleter!.completeError('Error getting directory tree: ${directoryTreeData['error']}');
              _pendingDirectoryTreeCompleter = null;
            }
            return;
          }
          
          bool isStreaming = directoryTreeData['streaming'] == true;
          int totalDirs = directoryTreeData['totalDirs'] ?? 0;
          List<dynamic> paths = directoryTreeData['paths'] ?? [];
          
          if (isStreaming) {
            // Streaming mode: accumulate paths in buffer
            if (!_isStreamingDirectoryTree) {
              // First message of stream - clear buffer
              _streamingDirectoryTreeBuffer.clear();
              // 0xFFFF (65535) means total is unknown
              _streamingTotalDirs = (totalDirs == 65535) ? 0 : totalDirs;
              _isStreamingDirectoryTree = true;
              print('Directory tree streaming started, totalDirs: $_streamingTotalDirs');
            }
            
            // Add paths from this message
            for (var path in paths) {
              if (path is String) {
                _streamingDirectoryTreeBuffer.add(path);
              }
            }
            
            print('Directory tree streaming: ${_streamingDirectoryTreeBuffer.length} paths received${_streamingTotalDirs > 0 ? ' / $_streamingTotalDirs' : ''}');
          } else {
            // Final or single message
            if (_isStreamingDirectoryTree) {
              // End of stream - combine buffer with this message
              for (var path in paths) {
                if (path is String) {
                  _streamingDirectoryTreeBuffer.add(path);
                }
              }
              
              // Create response with all accumulated paths
              Map<String, dynamic> directoryTreeResponse = {
                'type': 'DirectoryTree',
                'data': {
                  'pathType': directoryTreeData['pathType'] ?? 0,
                  'paths': List<String>.from(_streamingDirectoryTreeBuffer),
                },
              };
              
              _streamingDirectoryTreeBuffer.clear();
              _streamingTotalDirs = 0;
              _isStreamingDirectoryTree = false;
              
              print('Directory tree stream complete: ${directoryTreeResponse['data']['paths'].length} paths total');
              
              if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
                _pendingDirectoryTreeCompleter!.complete(directoryTreeResponse);
                print('Directory tree completer completed successfully (streaming)');
              }
            } else {
              // Single message (non-streaming)
              print('Directory tree single message: ${paths.length} paths');
              
              if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
                _pendingDirectoryTreeCompleter!.complete(data);
                print('Directory tree completer completed successfully (single message)');
              } else {
                print('Warning: Directory tree completer is null or already completed');
              }
            }
          }
        } else {
          print('Warning: DirectoryTree response missing data field: $data');
        }
        return; // Don't process further
      }
      
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        Map<String, dynamic> responseData = data['data'];
        
        // Handle file list response (supports streaming protocol)
        if (responseData.containsKey('action') && responseData['action'] == 'list') {
          // Check for errors first
          if (responseData.containsKey('error')) {
            print('File list error: ${responseData['error']}');
            _log('error', 'File list error', details: responseData['error'].toString());
            isLoadingFiles = false;
            fileListProgress = 0.0;
            _isStreamingFileList = false;
            _streamingFileBuffer.clear();
            _streamingTotalFiles = 0;
            _fileListTimeout?.cancel();
            _fileListTimeout = null;
            statusMessage = 'Error loading file list: ${responseData['error']}';
            notifyListeners();
            return;
          }
          
          if (responseData.containsKey('files') && responseData['files'] is List) {
            List<dynamic> files = responseData['files'];
            bool isStreaming = responseData['streaming'] == true;
            int totalFiles = responseData['totalFiles'] ?? 0;
            
            // Parse files from this message
            List<FileItem> parsedFiles = [];
            for (var file in files) {
              if (file is Map<String, dynamic>) {
                try {
                  parsedFiles.add(FileItem.fromJson(file));
                } catch (e) {
                  print('Error parsing file item: $e');
                }
              }
            }
            
            // CRITICAL: Check streaming flag FIRST before checking _isStreamingFileList
            // This ensures we properly handle the first streaming message
            if (isStreaming) {
              // Streaming mode: accumulate files in buffer
              if (!_isStreamingFileList) {
                // First message of stream - clear buffer and initialize
                // This should only happen once at the start of a new file list request
                _streamingFileBuffer.clear();
                // 0xFFFF (65535) means total is unknown
                _streamingTotalFiles = (totalFiles == 65535) ? 0 : totalFiles;
                _isStreamingFileList = true;
                _log('info', 'File list streaming started', 
                     details: 'Total files: ${_streamingTotalFiles > 0 ? _streamingTotalFiles : "unknown"}');
              }
              
              // Add files to buffer (accumulate across all streaming messages)
              final filesBefore = _streamingFileBuffer.length;
              _streamingFileBuffer.addAll(parsedFiles);
              final filesAfter = _streamingFileBuffer.length;
              
              // Update progress based on received/total files
              // If total is unknown (0 or was 65535), use indeterminate progress
              if (_streamingTotalFiles > 0) {
                fileListProgress = _streamingFileBuffer.length / _streamingTotalFiles;
              } else {
                // Indeterminate progress
                fileListProgress = 0.5;
              }
              
              _log('debug', 'File list streaming', 
                   details: 'Added ${filesAfter - filesBefore} files, total in buffer: ${_streamingFileBuffer.length}${_streamingTotalFiles > 0 ? '/$_streamingTotalFiles' : ''}');
              
              // CRITICAL: Update fileList during streaming so UI shows accumulated files
              // This ensures all files are visible, not just the last packet
              fileList = List.from(_streamingFileBuffer);
              notifyListeners();
            } else {
              // Final or single message (isStreaming == false)
              if (_isStreamingFileList) {
                // End of stream - combine buffer with this final message
                _streamingFileBuffer.addAll(parsedFiles);
                fileList = List.from(_streamingFileBuffer);
                _log('info', 'File list streaming complete', 
                     details: 'Total files: ${fileList.length} (buffer had ${_streamingFileBuffer.length - parsedFiles.length}, final message added ${parsedFiles.length})');
                _streamingFileBuffer.clear();
                _streamingTotalFiles = 0;
                _isStreamingFileList = false;
              } else {
                // Single message (non-streaming) - no previous streaming
                fileList = parsedFiles;
              }
              
              _log('info', 'File list complete', details: 'Path: $currentPath, Files: ${fileList.length}');
              
              // Save to cache
              if (fileList.isNotEmpty || files.isEmpty) {
                _fileCache[currentPath] = List.from(fileList);
                _cacheTimestamps[currentPath] = DateTime.now();
              }
              
              isLoadingFiles = false;
              fileListProgress = 0.0;
              _fileListTimeout?.cancel();
              _fileListTimeout = null;
              notifyListeners();
            }
          } else {
            // Invalid response format
            print('Invalid file list response format');
            _log('warning', 'Invalid file list response', details: 'Missing or invalid files array');
            isLoadingFiles = false;
            fileListProgress = 0.0;
            _isStreamingFileList = false;
            _streamingFileBuffer.clear();
            _streamingTotalFiles = 0;
            _fileListTimeout?.cancel();
            _fileListTimeout = null;
            notifyListeners();
          }
        }
      }
      
      // Handle file load response (direct response, not nested in 'data')
      if (data.containsKey('action') && data['action'] == 'load') {
        print('File load response received (direct)');
        _handleFileLoadResponse(data);
      }
      
      // Handle file load response (nested in 'data' field)
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        Map<String, dynamic> responseData = data['data'];
        if (responseData.containsKey('action') && responseData['action'] == 'load') {
          print('File load response received (nested in data)');
          _handleFileLoadResponse(responseData);
        }
        
        // Handle rename response
        if (responseData.containsKey('action') && responseData['action'] == 'rename') {
          print('Rename response received: $responseData');
          if (_pendingRenameCompleter != null && !_pendingRenameCompleter!.isCompleted) {
            _pendingRenameCompleter!.complete(responseData);
          }
        }
        
        // Handle delete response
        if (responseData.containsKey('action') && responseData['action'] == 'delete') {
          print('Delete response received: $responseData');
          // Add any specific delete handling if needed (e.g. completing a completer)
        }
        
        // Handle create-directory response
        if (responseData.containsKey('action') && responseData['action'] == 'create-directory') {
          print('Create directory response received: $responseData');
        }
        
        // Handle upload response
        if (responseData.containsKey('action') && responseData['action'] == 'upload') {
          print('Upload response received: $responseData');
          _handleFileUploadResponse(responseData);
        }
        
        // Handle copy response
        if (responseData.containsKey('action') && responseData['action'] == 'copy') {
          print('Copy response received: $responseData');
          if (_pendingCopyCompleter != null && !_pendingCopyCompleter!.isCompleted) {
            _pendingCopyCompleter!.complete(responseData);
          }
        }
        
        // Handle move response
        if (responseData.containsKey('action') && responseData['action'] == 'move') {
          print('Move response received: $responseData');
          if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
            _pendingMoveCompleter!.complete(responseData);
          }
        }
      }
      
      // Handle copy response (direct, not nested)
      if (data.containsKey('action') && data['action'] == 'copy') {
        print('Copy response received (direct): $data');
        if (_pendingCopyCompleter != null && !_pendingCopyCompleter!.isCompleted) {
          _pendingCopyCompleter!.complete(data);
        }
      }
      
      // Handle move response (direct, not nested)
      if (data.containsKey('action') && data['action'] == 'move') {
        print('Move response received (direct): $data');
        if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
          _pendingMoveCompleter!.complete(data);
        }
      }
      
      // Handle upload response (direct, not nested)
      if (data.containsKey('action') && data['action'] == 'upload') {
        print('Upload response received (direct): $data');
        _handleFileUploadResponse(data);
      }
    }
    
    notifyListeners();
  }

  /// Handle file load response
  void _handleFileLoadResponse(Map<String, dynamic> data) {
    print('Handling file load response: $data');
    
    if (data.containsKey('success') && data['success'] == true) {
      if (data.containsKey('content')) {
        String fileContent = data['content'];
        print('File content received, length: ${fileContent.length}');
        print('File content preview: ${fileContent.substring(0, fileContent.length > 100 ? 100 : fileContent.length)}...');
        
        // Store the file content for the current file reading operation
        _currentFileContent = fileContent;
        
        // If we have a pending file reading operation, complete it
        if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
          print('Completing pending file read completer with content length: ${fileContent.length}');
          _pendingFileReadCompleter!.complete(fileContent);
          _pendingFileReadCompleter = null;
        } else {
          print('No pending file read completer found');
        }
      } else {
        print('File load response missing content field');
        if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
          _pendingFileReadCompleter!.completeError('File content missing from response');
          _pendingFileReadCompleter = null;
        }
      }
    } else {
      String error = data['error'] ?? 'Unknown error loading file';
      print('File load failed: $error');
      if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
        _pendingFileReadCompleter!.completeError(error);
        _pendingFileReadCompleter = null;
      }
    }
  }

  /// Handle file upload response
  void _handleFileUploadResponse(dynamic data) {
    print('File upload response: $data');
    _log('info', 'File upload response', details: data.toString());
    
    // Check if we have a pending upload completer
    if (_pendingUploadCompleter != null && !_pendingUploadCompleter!.isCompleted) {
      if (data is Map<String, dynamic>) {
        if (data['success'] == true) {
          _pendingUploadCompleter!.complete(data);
        } else {
          String error = data['error'] ?? 'Upload failed';
          _pendingUploadCompleter!.completeError(error);
        }
      } else {
        _pendingUploadCompleter!.completeError('Invalid upload response');
      }
      _pendingUploadCompleter = null;
    }
    
    notifyListeners();
  }

  Completer<Map<String, dynamic>>? _pendingUploadCompleter;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  /// Upload file to ESP32 with chunking
  /// Reads file from device storage and uploads it in chunks
  Future<Map<String, dynamic>> uploadFile(
    File file,
    String targetPath, {
    int pathType = 0,
    Function(double progress)? onProgress,
  }) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }

    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    _log('INFO', 'Uploading file: ${file.path} to $targetPath');
    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      // Read file size
      final fileSize = await file.length();
      _log('INFO', 'File size: $fileSize bytes');

      // Calculate number of chunks
      // First chunk contains: [0x0D][pathLength:1][pathType:1][path:variable] in payload
      // Subsequent chunks contain only file data
      // Payload size = MAX_CHUNK_SIZE - PACKET_HEADER_SIZE - checksum(1)
      const int MAX_CHUNK_DATA_SIZE = FirmwareBinaryProtocol.MAX_CHUNK_SIZE - FirmwareBinaryProtocol.PACKET_HEADER_SIZE - 1;
      final int totalChunks = 1 + ((fileSize + MAX_CHUNK_DATA_SIZE - 1) ~/ MAX_CHUNK_DATA_SIZE);
      
      _log('INFO', 'Total chunks: $totalChunks');

      // Generate chunk ID
      final int chunkId = DateTime.now().millisecondsSinceEpoch & 0xFF;

      // Create completer for upload response
      _pendingUploadCompleter?.completeError('New upload started');
      _pendingUploadCompleter = Completer<Map<String, dynamic>>();

      // Send first chunk with path
      final firstChunk = FirmwareBinaryProtocol.createUploadFileStartCommand(
        targetPath,
        pathType: pathType,
        chunkId: chunkId,
        totalChunks: totalChunks,
      );
      await sendBinaryCommand(firstChunk);
      _uploadProgress = 1.0 / totalChunks;
      onProgress?.call(_uploadProgress);
      notifyListeners();

      // Read and send file data in chunks
      final fileStream = file.openRead();
      int chunkNum = 2; // Start from chunk 2 (chunk 1 is the path)
      int totalSent = 0;

      await for (final chunk in fileStream) {
        // Split chunk if it's too large
        int offset = 0;
        while (offset < chunk.length) {
          final int remaining = chunk.length - offset;
          final int chunkSize = remaining > MAX_CHUNK_DATA_SIZE ? MAX_CHUNK_DATA_SIZE : remaining;
          
          final Uint8List chunkData = Uint8List.fromList(chunk.sublist(offset, offset + chunkSize));
          
          // Create and send chunk
          final chunkCommand = FirmwareBinaryProtocol.createUploadFileChunkCommand(
            chunkData,
            chunkId,
            chunkNum,
            totalChunks,
          );
          
          await sendBinaryCommand(chunkCommand);
          
          totalSent += chunkSize;
          offset += chunkSize;
          chunkNum++;
          
          // Update progress
          _uploadProgress = totalSent / fileSize;
          onProgress?.call(_uploadProgress);
          notifyListeners();
          
          // Small delay to avoid overwhelming BLE stack
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      _log('INFO', 'File upload completed: $totalSent bytes sent in ${chunkNum - 1} chunks');

      // Wait for upload response with timeout
      final timeout = Timer(const Duration(seconds: 30), () {
        if (_pendingUploadCompleter != null && !_pendingUploadCompleter!.isCompleted) {
          _pendingUploadCompleter!.completeError('Upload timeout');
          _pendingUploadCompleter = null;
        }
      });

      try {
        final response = await _pendingUploadCompleter!.future;
        timeout.cancel();
        _uploadProgress = 1.0;
        onProgress?.call(1.0);
        _isUploading = false;
        notifyListeners();
        return response;
      } catch (e) {
        timeout.cancel();
        _isUploading = false;
        _uploadProgress = 0.0;
        notifyListeners();
        rethrow;
      } finally {
        _pendingUploadCompleter = null;
      }
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      _log('ERROR', 'File upload failed: $e');
      rethrow;
    }
  }

  // Scanner state management methods
  void updateDetectedSignals(List<DetectedSignal> newSignals) {
    detectedSignals.clear();
    detectedSignals.addAll(newSignals);
    notifyListeners();
  }

  void updateFrequencySpectrum(Map<String, double> newSpectrum) {
    frequencySpectrum = newSpectrum;
    notifyListeners();
  }

  void setScanning(bool scanning) {
    isScanning = scanning;
    notifyListeners();
  }

  void setSelectedModule(int module) {
    selectedModule = module;
    notifyListeners();
  }

  void setRssiThreshold(int threshold) {
    rssiThreshold = threshold;
    notifyListeners();
  }

  // Синхронная отправка команды (для простых команд)
  Future<String> sendCommandSync(String command) async {
    final completer = Completer<String>();
    final timeout = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete('');
      }
    });

    // Сохраняем старый callback
    final originalCallback = _onChunkComplete;
    final originalJsonCallback = _onJsonReceived;
    
    // Устанавливаем временный callback для чанков
    _onChunkComplete = (sessionId, data) {
      timeout.cancel();
      if (!completer.isCompleted) {
        completer.complete(data);
      }
    };

    // Устанавливаем временный callback для JSON ответов
    _onJsonReceived = (jsonData) {
      // Проверяем, что это command_response
      if (jsonData is Map && jsonData['type'] == 'command_response') {
        timeout.cancel();
        if (!completer.isCompleted) {
          completer.complete(jsonEncode(jsonData));
        }
        return;
      }
      
      // Если это данные сканирования (массив или объект)
      if (jsonData is List || (jsonData is Map && !jsonData.containsKey('type'))) {
        timeout.cancel();
        if (!completer.isCompleted) {
          completer.complete(jsonEncode(jsonData));
        }
      }
    };

    try {
      await sendCommand(command);
      final result = await completer.future;
      return result;
    } finally {
      // Восстанавливаем старые callbacks
      _onChunkComplete = originalCallback;
      _onJsonReceived = originalJsonCallback;
      timeout.cancel();
    }
  }

  // === Методы для работы с сигналами ===
  
  /// Парсинг файла сигнала
  /// [fileContent] - содержимое файла
  /// [filename] - имя файла (опционально)
  /// Возвращает SignalData или null если не удалось распарсить
  SignalData? parseSignalFile(String fileContent, {String? filename}) {
    try {
      final result = FileParserFactory.parseFile(fileContent, filename: filename);
      if (result.success) {
        _log('info', 'Successfully parsed signal file', details: filename);
        return result.signalData;
      } else {
        _log('error', 'Failed to parse signal file', details: result.errors.join(', '));
        return null;
      }
    } catch (e) {
      _log('error', 'Error parsing signal file', details: e.toString());
      return null;
    }
  }
  
  /// Генерация файла сигнала
  /// [signalData] - данные сигнала
  /// [format] - формат файла
  /// Возвращает содержимое файла или null если не удалось сгенерировать
  String? generateSignalFile(SignalData signalData, SignalFormat format) {
    try {
      final result = SignalGeneratorFactory.generateFromSignalData(signalData, format);
      if (result.success) {
        _log('info', 'Successfully generated signal file', details: format.description);
        return result.content;
      } else {
        _log('error', 'Failed to generate signal file', details: result.errors.join(', '));
        return null;
      }
    } catch (e) {
      _log('error', 'Error generating signal file', details: e.toString());
      return null;
    }
  }
  
  /// Валидация параметров записи
  /// [config] - конфигурация записи
  /// Возвращает список ошибок (пустой если все валидно)
  List<String> validateRecordConfig(RecordConfig config) {
    final errors = <String>[];
    
    // Проверка частоты
    if (!CC1101Values.isValidFrequency(config.frequency)) {
      final closest = CC1101Values.getClosestValidFrequency(config.frequency);
      if (closest != null) {
        errors.add('Invalid frequency ${config.frequency.toStringAsFixed(2)} MHz. Closest valid: ${closest.toStringAsFixed(2)} MHz');
      } else {
        errors.add('Invalid frequency ${config.frequency.toStringAsFixed(2)} MHz');
      }
    }
    
    // Проверка модуля
    if (config.module < 0) {
      errors.add('Invalid module number: ${config.module}');
    }
    
    // Проверка параметров в продвинутом режиме
    if (config.advancedMode) {
      if (config.dataRate != null && !CC1101Values.isValidDataRate(config.dataRate!)) {
        errors.add('Invalid data rate ${config.dataRate!.toStringAsFixed(2)} kBaud');
      }
      
      if (config.deviation != null && !CC1101Values.isValidDeviation(config.deviation!)) {
        errors.add('Invalid deviation ${config.deviation!.toStringAsFixed(2)} kHz');
      }
    }
    
    return errors;
  }
  
  /// Получение информации о файле сигнала
  /// [fileContent] - содержимое файла
  /// [filename] - имя файла (опционально)
  /// Возвращает информацию о файле
  Map<String, dynamic>? getSignalFileInfo(String fileContent, {String? filename}) {
    try {
      return FileParserFactory.getFileInfo(fileContent, filename: filename);
    } catch (e) {
      _log('error', 'Error getting file info', details: e.toString());
      return null;
    }
  }
  
  /// Получение списка поддерживаемых форматов файлов
  /// Возвращает список расширений файлов
  List<String> getSupportedFileExtensions() {
    return FileParserFactory.getSupportedExtensions();
  }
  
  /// Получение списка поддерживаемых форматов генерации
  /// Возвращает список форматов
  List<SignalFormat> getSupportedGenerationFormats() {
    return SignalGeneratorFactory.getSupportedFormats();
  }
  
  /// Создание конфигурации записи из SignalData
  /// [signalData] - данные сигнала
  /// [module] - номер модуля
  /// Возвращает конфигурацию записи
  RecordConfig createRecordConfigFromSignal(SignalData signalData, int module) {
    return RecordConfig.fromSignalData(signalData, module);
  }
  
  /// Получение калькулятора CC1101
  /// Возвращает экземпляр калькулятора
  CC1101Calculator getCC1101Calculator() {
    return CC1101Calculator();
  }
  
  /// Получение значений CC1101
  /// Возвращает класс с предопределенными значениями
  CC1101Values getCC1101Values() {
    return CC1101Values();
  }
  
  /// Отправка бинарной команды через Enhanced Protocol
  /// [command] - бинарная команда для отправки
  // Transmit signal from file
  Future<void> transmitFromFile(String filePath, {int? module, int repeat = 1, int? pathType}) async {
    if (!isConnected || txCharacteristic == null) {
      statusMessage = 'Not connected';
      _log('error', 'Failed to transmit: Not connected', details: 'File: $filePath');
      notifyListeners();
      throw Exception('Not connected to device');
    }

    try {
      // Find idle module if not specified
      int? selectedModule = module;
      if (selectedModule == null) {
        // Find first idle module
        if (cc1101Modules != null) {
          for (int i = 0; i < cc1101Modules!.length; i++) {
            final moduleMode = cc1101Modules![i]['mode']?.toString().toLowerCase();
            if (moduleMode == 'idle') {
              selectedModule = i;
              break;
            }
          }
        }
        
        // If no idle module found, throw error
        if (selectedModule == null) {
          statusMessage = 'No idle module available';
          _log('error', 'Failed to transmit: No idle module', details: 'File: $filePath');
          notifyListeners();
          throw Exception('No idle module available for transmission');
        }
      } else {
        // Check if specified module is idle
        if (cc1101Modules != null && selectedModule < cc1101Modules!.length) {
          final moduleMode = cc1101Modules![selectedModule]['mode']?.toString().toLowerCase();
          if (moduleMode != 'idle') {
            statusMessage = 'Module $selectedModule is not idle';
            _log('error', 'Failed to transmit: Module not idle', details: 'File: $filePath, Module: $selectedModule, Mode: $moduleMode');
            notifyListeners();
            throw Exception('Module $selectedModule is not idle (current mode: $moduleMode)');
          }
        }
      }
      
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      
      // Use the filePath as-is (it should be a relative path like "folder/file.sub" or just "file.sub")
      // Only extract filename if it's an absolute path starting with /DATA/
      String pathToUse = filePath;
      if (filePath.startsWith('/DATA/')) {
        // Extract relative path from /DATA/RECORDS/... or /DATA/SIGNALS/...
        final parts = filePath.split('/');
        if (parts.length > 3) {
          pathToUse = parts.sublist(3).join('/');
        } else {
          pathToUse = parts.last;
        }
      }
      
      _log('info', 'Transmitting signal from file', details: 'File: $pathToUse, pathType: $effectivePathType, Module: $selectedModule, Repeat: $repeat');
      
      // Use FirmwareBinaryProtocol to create properly formatted command with pathType and module
      final command = FirmwareBinaryProtocol.createTransmitFromFileCommand(pathToUse, pathType: effectivePathType, module: selectedModule);
      
      _log('debug', 'Sending transmitFromFile command', 
           details: 'File: $pathToUse, pathType: $effectivePathType, Module: $selectedModule, Command length: ${command.length} bytes');
      
      await sendBinaryCommand(command);
      
      statusMessage = 'transmittingSignal';
      lastCommandMessage = 'Transmitting from $filePath';
      notifyListeners();
    } catch (e) {
      _log('error', 'Failed to transmit signal', details: e.toString());
      statusMessage = 'Transmission failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendBinaryCommand(Uint8List command) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    try {
      await txCharacteristic!.write(command);
    } catch (e) {
      print('Error sending binary command: $e');
      throw Exception('Failed to send command: $e');
    }
  }

  /// Отправка команды записи сигнала
  /// Start jamming on specified module
  Future<void> sendStartJamCommand({
    required int module,
    required double frequency,
    int power = 7, // 0-7
    int patternType = 0, // 0=Random, 1=Alternating, 2=Continuous, 3=Custom
    int maxDurationMs = 60000, // 60 seconds default
    int cooldownMs = 5000, // 5 seconds default
    List<int>? customPattern, // Optional custom pattern bytes
  }) async {
    if (!isConnected || txCharacteristic == null) {
      _log('error', 'Cannot start jam: not connected');
      throw Exception('Not connected');
    }
    
    _log('command', 'Starting jam on module $module: freq=$frequency, power=$power, pattern=$patternType');
    
    final command = FirmwareBinaryProtocol.createStartJamCommand(
      module: module,
      frequency: frequency,
      power: power,
      patternType: patternType,
      maxDurationMs: maxDurationMs,
      cooldownMs: cooldownMs,
      customPattern: customPattern,
    );
    
    await sendBinaryCommand(command);
  }

  Future<void> sendRecordCommand({
    required double frequency,
    required int module,
    String? preset,
    int? modulation,
    double? deviation,
    double? rxBandwidth,
    double? dataRate,
  }) async {
    final command = FirmwareBinaryProtocol.createRequestRecordCommand(
      frequency: frequency,
      module: module,
      preset: preset,
      modulation: modulation,
      deviation: deviation,
      rxBandwidth: rxBandwidth,
      dataRate: dataRate,
    );
    
    await sendBinaryCommand(command);
  }

  /// Отправка команды idle (остановка операций)
  Future<void> sendIdleCommand(int module) async {
    final command = FirmwareBinaryProtocol.createRequestIdleCommand(module);
    await sendBinaryCommand(command);
  }

  /// Отправка команды передачи сигнала
  Future<void> sendTransmitCommand({
    required double frequency,
    required String data,
    int pulseDuration = 100,
  }) async {
    final command = FirmwareBinaryProtocol.createTransmitBinaryCommand(
      frequency,
      pulseDuration,
      data,
    );
    
    await sendBinaryCommand(command);
  }

  /// Отправка команды получения состояния устройства
  /// Send current time to ESP32 for synchronization
  Future<void> sendSetTimeCommand() async {
    if (!isConnected) {
      return;
    }

    try {
      final command = FirmwareBinaryProtocol.createSetTimeCommand(DateTime.now());
      await sendBinaryCommand(command);
      _log('info', 'Time synchronization command sent', details: 'Time: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      _log('error', 'Failed to send time synchronization command', details: e.toString());
      // Don't throw - time sync is not critical
    }
  }

  Future<void> sendGetStateCommand() async {
    final command = FirmwareBinaryProtocol.createGetStateCommand();
    await sendBinaryCommand(command);
  }



  /// Обработка переключения режима модуля
  /// Handle binary message (0x80-0xFF)
  void _handleBinaryMessage(Uint8List data) {
    // NOTE: Chunk buffers are now cleaned up BEFORE calling _handleBinaryMessage
    // So this check should rarely trigger, but we keep it as a safety measure
    // Only warn if buffers are active for a long time (might indicate stuck state)
    if (_chunkData.isNotEmpty) {
      // Don't return - allow processing since buffers should be cleaned up before this call
    }
    
    try {
      // Parse binary message and convert to JSON-compatible format
      final jsonData = BinaryMessageParser.parseBinaryMessage(data);
      
      if (jsonData != null) {
        _log('debug', 'Binary message received', details: '${jsonData['type']}: ${data.length} bytes');
        
        // Handle as if it was JSON (maintains compatibility with existing code)
        _handleCompleteResponse(jsonData);
      } else {
        _log('warning', 'Unknown binary message type', details: '0x${data[0].toRadixString(16)}');
      }
    } catch (e, stackTrace) {
      _log('error', 'Binary message parse error', details: '$e\n$stackTrace');
    }
  }

  void _handleModeSwitch(Map<String, dynamic> modeData) {
    print('_handleModeSwitch called with data: $modeData');
    int module = int.tryParse(modeData['module']?.toString() ?? '0') ?? 0;
    String mode = modeData['mode'] ?? 'Unknown';
    String previousMode = modeData['previousMode'] ?? 'Unknown';
    
    print('Mode switch: module=$module, mode=$mode, previous=$previousMode');
    print('Current cc1101Modules state before update: ${cc1101Modules?.map((m) => 'Module ${m['id']}: ${m['mode']}').join(', ')}');
    
    // Обновляем состояние записи
    if (mode == 'RecordSignal') {
      isRecording[module] = true;
      print('Module $module started recording');
    } else if (mode == 'Idle') {
      isRecording[module] = false;
      print('Module $module stopped recording');
    }
    
    // Обновляем состояние джамминга
    if (mode == 'Jamming') {
      isJamming[module] = true;
      print('Module $module started jamming');
    } else if (mode == 'Idle') {
      isJamming[module] = false;
      if (previousMode == 'Jamming') {
        print('Module $module stopped jamming');
      }
    }
    
    // Обновляем состояние поиска частоты
    if (mode == 'DetectSignal') {
      // Всегда устанавливаем флаг поиска частоты при переходе в DetectSignal
      isFrequencySearching[module] = true;
      print('Module $module frequency search started (ModeSwitch to DetectSignal)');
      _log('info', 'Frequency search started', details: 'Module: $module');
    } else if (mode == 'Idle' && previousMode == 'DetectSignal') {
      // Упрощенная логика: при переходе из DetectSignal в Idle сразу сбрасываем флаг
      // Контроллер автоматически переходит в Idle после обнаружения сигнала
      if (isFrequencySearching[module] == true) {
        isFrequencySearching[module] = false;
        print('Module $module frequency search stopped (ModeSwitch from DetectSignal to Idle)');
        _log('info', 'Frequency search stopped', details: 'Module: $module');
      }
    } else if (mode == 'Idle') {
      // При переходе в Idle из другого режима тоже сбрасываем, если флаг был установлен
      if (isFrequencySearching[module] == true) {
        isFrequencySearching[module] = false;
        print('Module $module frequency search stopped (ModeSwitch to Idle)');
      }
    }
    
    // Обновляем состояние модуля в cc1101Modules для отображения в UI
    if (cc1101Modules != null && module < cc1101Modules!.length) {
      cc1101Modules![module]['mode'] = mode;
      print('Updated module $module mode in cc1101Modules to: $mode');
    } else {
      // Если cc1101Modules не инициализирован, создаем базовую структуру
      if (cc1101Modules == null) {
        cc1101Modules = [];
      }
      // Убеждаемся, что есть достаточно элементов
      while (cc1101Modules!.length <= module) {
        cc1101Modules!.add({
          'id': cc1101Modules!.length,
          'mode': 'Unknown',
        });
      }
      cc1101Modules![module]['mode'] = mode;
      cc1101Modules![module]['id'] = module;
      print('Created/updated module $module in cc1101Modules with mode: $mode');
    }
    
    // Уведомляем UI об изменениях
    notifyListeners();
  }

  /// Обработка ответа состояния устройства
  void _handleStateResponse(Map<String, dynamic> stateData) {
    // Check if data is nested under 'data' key
    Map<String, dynamic> actualData = stateData;
    if (stateData.containsKey('data') && stateData['data'] is Map<String, dynamic>) {
      actualData = Map<String, dynamic>.from(stateData['data']);
    }
    
    // Обновляем состояние устройства
    if (actualData['device'] != null) {
      deviceStatus = actualData['device'];
      freeHeap = actualData['device']['freeHeap'];
    }
    
    if (actualData['cc1101'] != null) {
      cc1101Modules = List<Map<String, dynamic>>.from(actualData['cc1101']);
      
      // Обновляем состояние записи на основе текущих режимов модулей
      for (var module in cc1101Modules!) {
        int moduleId = module['id'] ?? 0;
        String mode = module['mode'] ?? 'Unknown';
        
        print('Module $moduleId: mode=$mode');
        
        // Обновляем состояние записи
        if (mode == 'RecordSignal') {
          isRecording[moduleId] = true;
          print('Module $moduleId is recording');
        } else {
          isRecording[moduleId] = false;
          print('Module $moduleId is not recording');
        }
        
        // Обновляем состояние джамминга
        if (mode == 'Jamming') {
          isJamming[moduleId] = true;
          print('Module $moduleId is jamming');
        } else {
          isJamming[moduleId] = false;
          print('Module $moduleId is not jamming');
        }
      }
      
      print('Final recording state: $isRecording');
    }
    
    print('Calling notifyListeners()');
    notifyListeners();
  }

  /// Проверка состояния записи для модуля
  bool isModuleRecording(int module) {
    return isRecording[module] ?? false;
  }

  /// Проверка состояния поиска частоты для модуля
  bool isModuleFrequencySearching(int module) {
    return isFrequencySearching[module] ?? false;
  }

  /// Проверка состояния джамминга для модуля
  bool isModuleJamming(int module) {
    return isJamming[module] ?? false;
  }

  /// Отправка команды с ожиданием ответа (для совместимости)
  /// [command] - команда для отправки (устаревший формат)
  /// Возвращает ответ от устройства
  Future<String> sendCommandWithResponse(String command) async {
    // TODO: Implement proper command response handling
    print('Warning: sendCommandWithResponse is deprecated, use sendBinaryCommand instead');
    return 'OK'; // Placeholder response
  }

  /// Переименование файла
  Future<bool> renameFile(String oldPath, String newName, {int? pathType}) async {
    if (!isConnected || txCharacteristic == null) return false;
    
    try {
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      String relativePath = oldPath;
      
      // Extract relative path (remove /DATA/xxx prefix if present)
      if (relativePath.startsWith('/DATA/')) {
        // Find the base path and extract the rest
        final parts = relativePath.split('/');
        // /DATA/RECORDS/subdir/file.txt -> subdir/file.txt
        if (parts.length > 3) {
          relativePath = parts.sublist(3).join('/');
        } else {
          relativePath = parts.last;
        }
      }
      
      // Build new path by preserving directory structure
      // e.g., "subdir/file.txt" -> "subdir/newname.txt"
      String newPath;
      final lastSlash = relativePath.lastIndexOf('/');
      if (lastSlash >= 0) {
        // File is in a subdirectory - preserve the path
        final directory = relativePath.substring(0, lastSlash);
        newPath = '$directory/$newName';
      } else {
        // File is in root
        newPath = newName;
      }
      
      _log('command', 'Renaming file: $relativePath -> $newPath (pathType: $effectivePathType)');
      
      // Use binary command with pathType
      final command = FirmwareBinaryProtocol.createRenameFileCommand(relativePath, newPath, pathType: effectivePathType);
      
      // Создаем completer для ожидания ответа
      _pendingRenameCompleter?.completeError('New rename operation started');
      _pendingRenameCompleter = Completer<Map<String, dynamic>>();
      
      await sendBinaryCommand(command);
      
      // Устанавливаем таймаут
      Timer timeout = Timer(const Duration(seconds: 10), () {
        if (_pendingRenameCompleter != null && !_pendingRenameCompleter!.isCompleted) {
          _pendingRenameCompleter!.completeError('Timeout waiting for rename response');
          _pendingRenameCompleter = null;
        }
      });
      
      try {
        // Ждем ответа
        final response = await _pendingRenameCompleter!.future;
        timeout.cancel();
        
        final success = response['success'] ?? false;
        if (success) {
          _log('info', 'File renamed successfully');
          await refreshFileList(); // Обновляем список файлов
          return true;
        } else {
          _log('error', 'Failed to rename file: ${response['error']}');
          return false;
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error waiting for rename response: $e');
        return false;
      } finally {
        _pendingRenameCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error renaming file: $e');
      return false;
    }
  }

  /// Удаление файла
  Future<bool> deleteFile(String filePath, {int? pathType}) async {
    if (!isConnected || txCharacteristic == null) return false;
    
    try {
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      String fileName = filePath;
      
      // Extract filename if full path provided
      if (filePath.startsWith('/DATA/')) {
        fileName = filePath.split('/').last;
      }
      
      _log('command', 'Deleting file: $fileName (pathType: $effectivePathType)');
      
      // Use FirmwareBinaryProtocol to create properly formatted command
      final command = FirmwareBinaryProtocol.createRemoveFileCommand(fileName, pathType: effectivePathType);
      
      await sendBinaryCommand(command);
      
      // Wait for response
      final response = await _waitForResponse();
      if (response != null && response['action'] == 'delete') {
        final success = response['success'] ?? false;
        if (success) {
          _log('info', 'File deleted successfully');
          await refreshFileList(); // Обновляем список файлов
          return true;
        } else {
          _log('error', 'Failed to delete file: ${response['error']}');
          return false;
        }
      }
      
      return false;
    } catch (e) {
      _log('error', 'Error deleting file: $e');
      return false;
    }
  }

  /// Перемещение файла
  Future<bool> moveFile(String sourcePath, String destinationPath, {int? sourcePathType, int? destPathType}) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    try {
      // Use provided pathTypes or current (for backward compatibility)
      int effectiveSourcePathType = sourcePathType ?? currentPathType;
      int effectiveDestPathType = destPathType ?? currentPathType;
      
      _log('command', 'Moving file: $sourcePath -> $destinationPath (sourcePathType: $effectiveSourcePathType, destPathType: $effectiveDestPathType)');
      
      // Create completer for move response
      _pendingMoveCompleter?.completeError('New move request started');
      _pendingMoveCompleter = Completer<Map<String, dynamic>>();
      
      // Create binary command with separate pathTypes
      final command = FirmwareBinaryProtocol.createMoveFileCommand(
        sourcePath,
        destinationPath,
        sourcePathType: effectiveSourcePathType,
        destPathType: effectiveDestPathType,
      );
      
      // Send command
      await sendBinaryCommand(command);
      
      // Wait for response with timeout
      final timeout = Timer(const Duration(seconds: 30), () {
        if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
          _pendingMoveCompleter!.completeError('Move timeout');
          _pendingMoveCompleter = null;
        }
      });
      
      try {
        final response = await _pendingMoveCompleter!.future;
        timeout.cancel();
        
        if (response['success'] == true) {
          _log('info', 'File moved successfully');
          
          // Extract destination path from response
          String? destPath = response['path'] as String?;
          if (destPath != null) {
            // Extract relative directory path from full path (removes /DATA/RECORDS etc.)
            // Use effectiveDestPathType (destination storage) for path extraction
            String destDirectory = _extractRelativePath(destPath, effectiveDestPathType);
            
            // Check if we're currently viewing the destination directory
            if (destDirectory == currentPath) {
              // Same directory - refresh the list
              await refreshFileList(forceRefresh: true);
            } else {
              // Different directory - invalidate cache for destination
              invalidateCacheForPath(destDirectory);
            }
          } else {
            // If dest path not in response, just refresh current directory
            await refreshFileList(forceRefresh: true);
          }
          
          return true;
        } else {
          String error = response['error'] ?? 'Unknown error';
          _log('error', 'Failed to move file: $error');
          throw Exception(error);
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error moving file: $e');
        rethrow;
      } finally {
        _pendingMoveCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error moving file: $e');
      rethrow;
    }
  }

  /// Копирование файла
  Completer<Map<String, dynamic>>? _pendingCopyCompleter;
  
  /// Перемещение файла
  Completer<Map<String, dynamic>>? _pendingMoveCompleter;

  Future<bool> copyFile(String sourcePath, String destinationPath) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    try {
      _log('command', 'Copying file: $sourcePath -> $destinationPath');
      
      // Create completer for copy response
      _pendingCopyCompleter?.completeError('New copy request started');
      _pendingCopyCompleter = Completer<Map<String, dynamic>>();
      
      // Create binary command
      final command = FirmwareBinaryProtocol.createCopyFileCommand(
        sourcePath,
        destinationPath,
        pathType: currentPathType,
      );
      
      // Send command
      await sendBinaryCommand(command);
      
      // Wait for response with timeout
      final timeout = Timer(const Duration(seconds: 30), () {
        if (_pendingCopyCompleter != null && !_pendingCopyCompleter!.isCompleted) {
          _pendingCopyCompleter!.completeError('Copy timeout');
          _pendingCopyCompleter = null;
        }
      });
      
      try {
        final response = await _pendingCopyCompleter!.future;
        timeout.cancel();
        
        if (response['success'] == true) {
          _log('info', 'File copied successfully');
          
          // Extract destination path from response
          String? destPath = response['dest'] as String?;
          if (destPath != null) {
            // Extract relative directory path from full path (removes /DATA/RECORDS etc.)
            String destDirectory = _extractRelativePath(destPath, currentPathType);
            
            // Check if we're currently viewing the destination directory
            if (destDirectory == currentPath) {
              // Same directory - refresh the list
              await refreshFileList(forceRefresh: true);
            } else {
              // Different directory - invalidate cache for destination
              invalidateCacheForPath(destDirectory);
            }
          } else {
            // If dest path not in response, just refresh current directory
            await refreshFileList(forceRefresh: true);
          }
          
          return true;
        } else {
          final error = response['error'] ?? 'Copy failed';
          _log('error', 'Failed to copy file: $error');
          throw Exception(error);
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error copying file: $e');
        rethrow;
      } finally {
        _pendingCopyCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error copying file: $e');
      rethrow;
    }
  }

  /// Создание директории
  Future<bool> createDirectory(String path, {int? pathType}) async {
    if (!isConnected || txCharacteristic == null) return false;
    
    try {
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      String dirName = path;
      
      // Extract directory name if full path provided
      if (path.startsWith('/DATA/')) {
        dirName = path.split('/').last;
      }
      
      _log('command', 'Creating directory: $dirName (pathType: $effectivePathType)');
      
      // Use binary command with pathType
      final command = FirmwareBinaryProtocol.createCreateDirectoryCommand(dirName, pathType: effectivePathType);
      
      await sendBinaryCommand(command);
      
      // Wait for response
      final response = await _waitForResponse();
      if (response != null && response['action'] == 'create-directory') {
        final success = response['success'] ?? false;
        if (success) {
          _log('info', 'Directory created successfully');
          await refreshFileList(); // Обновляем список файлов
          return true;
        } else {
          _log('error', 'Failed to create directory: ${response['error']}');
          return false;
        }
      } else {
        _log('error', 'Invalid response for create directory');
        return false;
      }
      
      return false;
    } catch (e) {
      _log('error', 'Error creating directory: $e');
      return false;
    }
  }

  /// Получение дерева директорий для выбранного хранилища
  Future<List<DirectoryTreeNode>> getDirectoryTree({int pathType = 0}) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    _log('info', 'Getting directory tree', details: 'pathType: $pathType');
    
    // Отменяем предыдущий запрос, если есть
    if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
      _pendingDirectoryTreeCompleter!.completeError('New directory tree request started');
    }
    
    // Reset streaming state
    _isStreamingDirectoryTree = false;
    _streamingDirectoryTreeBuffer.clear();
    _streamingTotalDirs = 0;
    
    _pendingDirectoryTreeCompleter = Completer<Map<String, dynamic>>();
    print('Created directory tree completer for pathType: $pathType');
    
    // Отправляем команду получения дерева директорий
    final command = FirmwareBinaryProtocol.createGetDirectoryTreeCommand(pathType: pathType);
    print('Sending getDirectoryTree command (pathType: $pathType, command length: ${command.length})');
    await sendBinaryCommand(command);
    print('Command sent, waiting for response...');
    
    // Устанавливаем таймаут
    Timer timeout = Timer(const Duration(seconds: 30), () {
      if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
        _pendingDirectoryTreeCompleter!.completeError('Timeout waiting for directory tree');
        _pendingDirectoryTreeCompleter = null;
      }
    });
    
    try {
      final response = await _pendingDirectoryTreeCompleter!.future;
      timeout.cancel();
      
      print('Received directory tree response: $response');
      
      // Парсим ответ
      if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
        Map<String, dynamic> data = response['data'];
        
        if (data.containsKey('error')) {
          throw Exception('Error getting directory tree: ${data['error']}');
        }
        
        if (data.containsKey('paths') && data['paths'] is List) {
          List<dynamic> paths = data['paths'];
          print('Building tree from ${paths.length} paths');
          
          // Rebuild tree from flat paths
          List<DirectoryTreeNode> tree = _rebuildDirectoryTree(paths.cast<String>(), pathType);
          
          _log('info', 'Directory tree received', details: '${paths.length} directories');
          return tree;
        } else {
          print('Response data missing paths field. Keys: ${data.keys.toList()}');
        }
      } else {
        print('Response missing data field or data is not Map. Response keys: ${response.keys.toList()}');
      }
      
      throw Exception('Invalid directory tree response format: $response');
    } catch (e) {
      timeout.cancel();
      _log('error', 'Error getting directory tree: $e');
      rethrow;
    } finally {
      _pendingDirectoryTreeCompleter = null;
    }
  }

  /// Rebuild directory tree from flat list of absolute paths
  List<DirectoryTreeNode> _rebuildDirectoryTree(List<String> paths, int pathType) {
    Map<String, DirectoryTreeNode> nodeMap = {};
    List<DirectoryTreeNode> roots = [];
    
    // Sort paths by length to process parents before children
    paths.sort((a, b) => a.length.compareTo(b.length));
    
    for (String fullPath in paths) {
      // Get base path based on pathType
      String basePath = _getBasePathForPathType(pathType) ?? '';
      
      // Extract relative path from absolute path
      String relativePath = fullPath;
      if (fullPath.startsWith(basePath)) {
        relativePath = fullPath.substring(basePath.length);
      }
      if (!relativePath.startsWith('/')) relativePath = '/$relativePath';
      
      String name = relativePath.split('/').last;
      if (name.isEmpty && relativePath == '/') name = '/';
      
      DirectoryTreeNode node = DirectoryTreeNode(
        name: name,
        path: relativePath,
        directories: [],
      );
      
      nodeMap[fullPath] = node;
      
      // Find parent path
      int lastSlash = fullPath.lastIndexOf('/');
      if (lastSlash != -1) {
        String parentPath = fullPath.substring(0, lastSlash);
        if (nodeMap.containsKey(parentPath)) {
          nodeMap[parentPath]!.directories.add(node);
        } else {
          // No parent found in map, it's a root for our purposes
          // (though it might be deep in the filesystem)
          if (!roots.contains(node)) roots.add(node);
        }
      } else {
        roots.add(node);
      }
    }
    
    return roots;
  }

  /// Проверка доступности модуля для операций
  bool isModuleAvailable(int moduleIndex) {
    if (cc1101Modules == null || moduleIndex >= cc1101Modules!.length) {
      return false;
    }
    
    final module = cc1101Modules![moduleIndex];
    final mode = module['mode']?.toString().toLowerCase() ?? 'unknown';
    
    // Модуль доступен только если он в режиме Idle
    return mode == 'idle';
  }

  /// Получение списка доступных модулей
  List<int> getAvailableModules() {
    if (cc1101Modules == null) return [];
    
    final availableModules = <int>[];
    for (int i = 0; i < cc1101Modules!.length; i++) {
      if (isModuleAvailable(i)) {
        availableModules.add(i);
      }
    }
    
    return availableModules;
  }

  /// Получение состояния модуля
  String getModuleStatus(int moduleIndex) {
    if (cc1101Modules == null || moduleIndex >= cc1101Modules!.length) {
      return 'Unknown';
    }
    
    return cc1101Modules![moduleIndex]['mode']?.toString() ?? 'Unknown';
  }

  /// Ожидание ответа от устройства
  Future<Map<String, dynamic>?> _waitForResponse() async {
    final completer = Completer<Map<String, dynamic>?>();
    
    // Устанавливаем таймаут
    Timer timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    
    try {
      // В реальной реализации здесь должен быть механизм ожидания ответа
      // Пока возвращаем заглушку
      await Future.delayed(const Duration(milliseconds: 100));
      return {'type': 'success', 'success': true};
    } finally {
      timeout.cancel();
    }
  }

  /// Сохранение файла в директорию сигналов с выбором имени
  Future<void> saveFileToSignalsWithName(String sourcePath, String targetName, {int pathType = 1, DateTime? preserveDate}) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }

    try {
      // Use FirmwareBinaryProtocol to create properly formatted command
      final command = FirmwareBinaryProtocol.createSaveToSignalsWithNameCommand(
        sourcePath, 
        targetName, 
        pathType: pathType,
        preserveDate: preserveDate,
      );
      
      await sendBinaryCommand(command);
      _log('info', 'File save with name command sent', details: 'Source: $sourcePath, Target: $targetName, PathType: $pathType${preserveDate != null ? ", Date: $preserveDate" : ""}');
    } catch (e) {
      _log('error', 'Failed to send save with name command', details: e.toString());
      rethrow;
    }
  }

  /// Запуск поиска частоты для модуля
  Future<void> startFrequencySearch(int module, {int minRssi = -65}) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }

    try {
      // Set pending frequency searching flag (will be confirmed by ModeSwitch)
      isFrequencySearching[module] = true;
      notifyListeners();
      
      final command = FirmwareBinaryProtocol.createFrequencySearchCommand(module, minRssi);
      await sendBinaryCommand(command);
      _log('info', 'Frequency search command sent', details: 'Module: $module, MinRSSI: $minRssi');
    } catch (e) {
      // Reset flag on error
      isFrequencySearching[module] = false;
      notifyListeners();
      _log('error', 'Failed to start frequency search', details: e.toString());
      rethrow;
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

