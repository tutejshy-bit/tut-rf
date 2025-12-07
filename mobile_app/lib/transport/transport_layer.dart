// Абстрактный интерфейс транспортного слоя для Flutter
abstract class ITransportLayer {
  // Инициализация транспортного слоя
  Future<bool> initialize();
  
  // Отправка данных
  Future<bool> sendData(String data);
  
  // Отправка бинарных данных
  Future<bool> sendBinaryData(List<int> data);
  
  // Установка callback для получения данных
  void setDataReceivedCallback(Function(String) callback);
  
  // Проверка подключения
  bool get isConnected;
  
  // Получение статистики
  Map<String, int> getStats();
  
  // Очистка ресурсов
  void dispose();
}

// Конкретная реализация для BLE с Binary Protocol
class BLEBinaryTransport implements ITransportLayer {
  late Function(String) _dataCallback;
  bool _isConnected = false;
  
  // Статистика
  int _packetsSent = 0;
  int _packetsReceived = 0;
  int _errors = 0;
  
  // Буферы для сборки данных
  final Map<int, ChunkBuffer> _chunkBuffers = {};
  
  // Структура пакета
  static const int PACKET_HEADER_SIZE = 7; // Updated: dataLen is now 2 bytes
  static const int MAX_DATA_SIZE = 500; // Updated for Bluetooth 5.0
  
  @override
  Future<bool> initialize() async {
    print('Initializing BLE Binary Transport');
    // Здесь будет инициализация BLE
    return true;
  }
  
  @override
  Future<bool> sendData(String data) async {
    if (!_isConnected) {
      print('Not connected, cannot send data');
      return false;
    }
    
    print('Sending data: ${data.length} bytes');
    
    // Разбиваем данные на маленькие пакеты
    int totalChunks = (data.length + MAX_DATA_SIZE - 1) ~/ MAX_DATA_SIZE;
    int chunkId = DateTime.now().millisecondsSinceEpoch & 0xFF;
    
    for (int i = 0; i < totalChunks; i++) {
      int chunkNum = i + 1;
      
      // Создаем пакет
      List<int> packet = _createPacket(
        type: 0x01, // data
        chunkId: chunkId,
        chunkNum: chunkNum,
        totalChunks: totalChunks,
        data: data.substring(i * MAX_DATA_SIZE, 
              (i + 1) * MAX_DATA_SIZE > data.length ? data.length : (i + 1) * MAX_DATA_SIZE),
      );
      
      // Отправляем пакет
      if (!await _sendPacket(packet)) {
        print('Failed to send packet $chunkNum');
        _errors++;
        return false;
      }
      
      // Ждем подтверждение
      if (!await _waitForACK(chunkId, chunkNum, 1000)) {
        print('No ACK for packet $chunkNum, retrying');
        // Повторяем отправку
        if (!await _sendPacket(packet)) {
          print('Retry failed for packet $chunkNum');
          _errors++;
          return false;
        }
      }
      
      _packetsSent++;
      
      // Короткая пауза
      await Future.delayed(const Duration(milliseconds: 5));
    }
    
    print('Data sent successfully: $totalChunks chunks');
    return true;
  }
  
  @override
  Future<bool> sendBinaryData(List<int> data) async {
    // Конвертируем в String для унификации
    String dataStr = String.fromCharCodes(data);
    return await sendData(dataStr);
  }
  
  @override
  void setDataReceivedCallback(Function(String) callback) {
    _dataCallback = callback;
  }
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  Map<String, int> getStats() {
    return {
      'packetsSent': _packetsSent,
      'packetsReceived': _packetsReceived,
      'errors': _errors,
    };
  }
  
  @override
  void dispose() {
    _chunkBuffers.clear();
  }
  
  // Создание пакета
  List<int> _createPacket({
    required int type,
    required int chunkId,
    required int chunkNum,
    required int totalChunks,
    required String data,
  }) {
    List<int> packet = List.filled(PACKET_HEADER_SIZE + data.length, 0);
    
    packet[0] = 0xAA; // magic
    packet[1] = type;
    packet[2] = chunkId;
    packet[3] = chunkNum;
    packet[4] = totalChunks;
    packet[5] = data.length & 0xFF;        // Data length (low byte)
    packet[6] = (data.length >> 8) & 0xFF; // Data length (high byte)
    
    // Копируем данные
    for (int i = 0; i < data.length; i++) {
      packet[7 + i] = data.codeUnitAt(i);  // Data starts at offset 7
    }
    
    // Вычисляем checksum
    packet[7 + data.length] = _calculateChecksum(packet, data.length);
    
    return packet;
  }
  
  // Вычисление контрольной суммы
  int _calculateChecksum(List<int> packet, int dataLength) {
    int checksum = packet[0] ^ packet[1] ^ packet[2] ^ packet[3] ^ packet[4] ^ packet[5] ^ packet[6];
    
    for (int i = 0; i < dataLength; i++) {
      checksum ^= packet[7 + i];
    }
    
    return checksum;
  }
  
  // Отправка пакета
  Future<bool> _sendPacket(List<int> packet) async {
    // Здесь будет реальная отправка через BLE
    print('Sending packet: ${packet.length} bytes');
    return true;
  }
  
  // Ожидание подтверждения
  Future<bool> _waitForACK(int chunkId, int chunkNum, int timeoutMs) async {
    // Упрощенная реализация - всегда возвращаем true
    // В полной реализации здесь будет проверка полученных ACK
    await Future.delayed(Duration(milliseconds: timeoutMs));
    return true;
  }
  
  // Обработка полученного пакета
  void _processReceivedPacket(List<int> packet) {
    if (packet.length < PACKET_HEADER_SIZE) {
      print('Invalid packet size: ${packet.length}');
      _errors++;
      return;
    }
    
    if (packet[0] != 0xAA) {
      print('Invalid packet magic: 0x${packet[0].toRadixString(16)}');
      _errors++;
      return;
    }
    
    int type = packet[1];
    int chunkId = packet[2];
    int chunkNum = packet[3];
    int totalChunks = packet[4];
    int dataLength = packet[5] | (packet[6] << 8);  // Little-endian: 2 bytes
    
    // Проверяем checksum
    int calculatedChecksum = _calculateChecksum(packet, dataLength);
    if (packet[7 + dataLength] != calculatedChecksum) {
      print('Checksum mismatch for packet $chunkNum');
      _errors++;
      return;
    }
    
    _packetsReceived++;
    
    if (type == 0x01) { // data packet
      // Обрабатываем данные
      if (!_chunkBuffers.containsKey(chunkId)) {
        _chunkBuffers[chunkId] = ChunkBuffer(
          totalChunks: totalChunks,
          receivedChunks: 0,
          timestamp: DateTime.now(),
        );
      }
      
      ChunkBuffer buffer = _chunkBuffers[chunkId]!;
      
      // Добавляем данные
      String chunkData = String.fromCharCodes(packet.sublist(7, 7 + dataLength));
      buffer.data += chunkData;
      buffer.receivedChunks++;
      
      // Проверяем, все ли чанки получены
      if (buffer.receivedChunks >= buffer.totalChunks) {
        // Вызываем callback с полными данными
        if (_dataCallback != null) {
          _dataCallback(buffer.data);
        }
        
        // Удаляем буфер
        _chunkBuffers.remove(chunkId);
      }
      
      // Отправляем ACK
      _sendACK(chunkId, chunkNum);
      
    } else if (type == 0x02) { // ACK
      print('Received ACK for chunk $chunkNum');
    } else if (type == 0x03) { // NAK
      print('Received NAK for chunk $chunkNum');
    }
    
    // Очищаем старые буферы
    _cleanupOldChunks();
  }
  
  // Отправка ACK
  Future<void> _sendACK(int chunkId, int chunkNum) async {
    List<int> ackPacket = _createPacket(
      type: 0x02, // ACK
      chunkId: chunkId,
      chunkNum: chunkNum,
      totalChunks: 0,
      data: '',
    );
    
    await _sendPacket(ackPacket);
  }
  
  // Очистка старых буферов
  void _cleanupOldChunks() {
    DateTime now = DateTime.now();
    _chunkBuffers.removeWhere((key, buffer) {
      return now.difference(buffer.timestamp).inSeconds > 30;
    });
  }
}

// Буфер для сборки чанков
class ChunkBuffer {
  String data = '';
  int totalChunks;
  int receivedChunks;
  DateTime timestamp;
  
  ChunkBuffer({
    required this.totalChunks,
    required this.receivedChunks,
    required this.timestamp,
  });
}

// Фабрика для создания транспортных слоев
class TransportFactory {
  static const int BLE_JSON = 0;
  static const int BLE_BINARY = 1;
  static const int BLE_FAST = 2;
  
  static ITransportLayer createTransport(int type) {
    switch (type) {
      case BLE_BINARY:
        return BLEBinaryTransport();
      case BLE_JSON:
        // TODO: Реализовать JSON транспорт
        throw UnimplementedError('JSON transport not implemented');
      case BLE_FAST:
        // TODO: Реализовать быстрый транспорт
        throw UnimplementedError('Fast transport not implemented');
      default:
        throw ArgumentError('Unknown transport type: $type');
    }
  }
}
