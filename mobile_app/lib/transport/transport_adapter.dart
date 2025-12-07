import 'transport_layer.dart';

// Адаптер для интеграции транспортного слоя с существующим кодом Flutter
class TransportAdapter {
  ITransportLayer? _transport;
  Function(String)? _dataCallback;
  
  // Статистика
  int _totalCommands = 0;
  int _successfulCommands = 0;
  int _failedCommands = 0;
  
  // Инициализация
  Future<bool> initialize(int transportType) async {
    print('Initializing transport adapter with type: $transportType');
    
    try {
      // Создаем транспортный слой
      _transport = TransportFactory.createTransport(transportType);
      
      // Инициализируем транспорт
      if (!await _transport!.initialize()) {
        print('Failed to initialize transport layer');
        _transport = null;
        return false;
      }
      
      // Устанавливаем callback для получения данных
      _transport!.setDataReceivedCallback((String data) {
        _onDataReceived(data);
      });
      
      print('Transport adapter initialized successfully');
      return true;
      
    } catch (e) {
      print('Error initializing transport adapter: $e');
      _transport = null;
      return false;
    }
  }
  
  // Обработка команд
  Future<void> handleCommand(String command) async {
    if (_transport == null) {
      print('Transport not initialized');
      return;
    }
    
    _totalCommands++;
    print('Handling command: $command');
    
    try {
      // Отправляем команду
      bool success = await _transport!.sendData(command);
      
      if (success) {
        _successfulCommands++;
        print('Command sent successfully');
      } else {
        _failedCommands++;
        print('Failed to send command');
      }
      
    } catch (e) {
      _failedCommands++;
      print('Command processing failed: $e');
    }
  }
  
  // Получение статистики
  Map<String, int> getStats() {
    Map<String, int> stats = {
      'totalCommands': _totalCommands,
      'successfulCommands': _successfulCommands,
      'failedCommands': _failedCommands,
    };
    
    // Добавляем статистику транспортного слоя
    if (_transport != null) {
      Map<String, int> transportStats = _transport!.getStats();
      stats.addAll(transportStats);
    }
    
    return stats;
  }
  
  // Проверка подключения
  bool get isConnected => _transport?.isConnected ?? false;
  
  // Переключение протокола
  Future<bool> switchProtocol(int newType) async {
    print('Switching protocol to type: $newType');
    
    if (_transport == null) {
      print('No transport to switch');
      return false;
    }
    
    try {
      // Сохраняем текущее состояние
      bool wasConnected = _transport!.isConnected;
      
      // Очищаем старый транспорт
      _transport!.dispose();
      _transport = null;
      
      // Создаем новый транспорт
      _transport = TransportFactory.createTransport(newType);
      
      // Инициализируем новый транспорт
      if (!await _transport!.initialize()) {
        print('Failed to initialize new transport');
        _transport = null;
        return false;
      }
      
      // Восстанавливаем callback
      _transport!.setDataReceivedCallback((String data) {
        _onDataReceived(data);
      });
      
      print('Protocol switched successfully');
      return true;
      
    } catch (e) {
      print('Error switching protocol: $e');
      _transport = null;
      return false;
    }
  }
  
  // Обработка полученных данных
  void _onDataReceived(String data) {
    print('Data received: ${data.length} bytes');
    print('Data content: $data');
    
    // Вызываем callback если установлен
    if (_dataCallback != null) {
      _dataCallback!(data);
    }
  }
  
  // Установка callback для получения данных
  void setDataReceivedCallback(Function(String) callback) {
    _dataCallback = callback;
  }
  
  // Очистка ресурсов
  void dispose() {
    if (_transport != null) {
      _transport!.dispose();
      _transport = null;
    }
  }
}

// Глобальный экземпляр адаптера
TransportAdapter? gTransportAdapter;
