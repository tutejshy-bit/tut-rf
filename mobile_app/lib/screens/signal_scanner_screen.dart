import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../models/detected_signal.dart';

class SignalScannerScreen extends StatefulWidget {
  const SignalScannerScreen({super.key});

  @override
  State<SignalScannerScreen> createState() => _SignalScannerScreenState();
}

class _SignalScannerScreenState extends State<SignalScannerScreen> 
    with TickerProviderStateMixin {
  
  // Режимы сканирования
  bool _isListMode = true;
  bool _isScanning = false;
  int _selectedModule = 0; // 0 или 1
  
  // Параметры для режима списка
  double _rssiThreshold = 50.0; // Порог RSSI (0-100)
  
  // Данные сканирования
  // Remove local state - use BleProvider instead
  // List<DetectedSignal> _detectedSignals = [];
  Map<String, double> _frequencySpectrum = {}; // Частота -> RSSI
  
  // Анимации для эквалайзера
  late AnimationController _spectrumAnimationController;
  late Animation<double> _spectrumAnimation;
  
  // Таймеры
  Timer? _scanTimer;
  
  // Частоты для сканирования (из проекта esp32cc1101)
  final List<double> _scanFrequencies = [
    300.00, 303.87, 304.25, 310.00, 315.00, 318.00,
    390.00, 418.00, 433.07, 433.92, 434.42, 434.77,
    438.90, 868.35, 868.865, 868.95, 915.00, 925.00
  ];

  @override
  void initState() {
    super.initState();
    
    // Инициализация анимации для спектрограммы
    _spectrumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _spectrumAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _spectrumAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _spectrumAnimationController.dispose();
    super.dispose();
  }


  // Запуск сканирования
  Future<void> _startScanning() async {
    if (_isScanning) return;

    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    setState(() {
      _isScanning = true;
      // Не очищаем список при запуске - сохраняем историю
      _frequencySpectrum.clear();
    });

    // Запускаем анимацию спектрограммы
    if (!_isListMode) {
      _spectrumAnimationController.repeat();
    }

    try {
      // Send scan command to ESP32
      String command = 'scan -100 $_selectedModule';
      print('Scanner: Sending start command: $command');
      String response = await bleProvider.sendCommandSync(command);
      print('Scanner: Start command response: $response');
      
      // Start periodic data updates
      _startPeriodicUpdate();
      
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _spectrumAnimationController.stop();
      
      if (mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError('Ошибка запуска сканирования: $e');
      }
    }
  }

  // Очистка списка сигналов
  void _clearSignals() {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    bleProvider.updateDetectedSignals([]); // Clear detected signals
    setState(() {
      _frequencySpectrum.clear();
    });
  }

  // Остановка сканирования
  Future<void> _stopScanning() async {
    if (!_isScanning) return;

    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    setState(() {
      _isScanning = false;
    });

    _scanTimer?.cancel();
    _spectrumAnimationController.stop();

    try {
      // Send idle command to stop scanning
      String command = 'idle $_selectedModule';
      await bleProvider.sendCommand(command);
    } catch (e) {
      if (mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError('Ошибка остановки сканирования: $e');
      }
    }
  }

  // Периодическое обновление данных
  void _startPeriodicUpdate() {
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!_isScanning) {
        timer.cancel();
        return;
      }

      await _updateScanData();
    });
  }

  // Обновление данных сканирования
  Future<void> _updateScanData() async {
    if (!mounted) return; // Check if widget is still mounted
    
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    try {
      if (_isListMode) {
        // Get list of detected signals
        String command = 'scan -100 $_selectedModule';
        print('Scanner: Sending command: $command');
        String response = await bleProvider.sendCommandSync(command);
        print('Scanner: Received response: $response');
        
        if (response.isNotEmpty) {
          // Проверяем, что это JSON массив
          if (response.startsWith('[') && response.endsWith(']')) {
            try {
              List<dynamic> signalsJson = jsonDecode(response);
              List<DetectedSignal> newSignals = signalsJson
                  .map((json) => DetectedSignal.fromJson(json))
                  .toList();
              
              print('Scanner: Parsed ${newSignals.length} signals');
              
              if (mounted) {
                // Update BleProvider with new signals instead of local state
                final bleProvider = Provider.of<BleProvider>(context, listen: false);
                List<DetectedSignal> currentSignals = List.from(bleProvider.detectedSignals);
                
                // Add new signals to the beginning
                for (DetectedSignal newSignal in newSignals) {
                  currentSignals.insert(0, newSignal);
                }
                
                // Limit list size (max 100 signals)
                if (currentSignals.length > 100) {
                  currentSignals = currentSignals.take(100).toList();
                }
                
                // Sort by timestamp (newest first)
                currentSignals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                
                // Update BleProvider
                bleProvider.updateDetectedSignals(currentSignals);
                
                print('Scanner: UI updated with ${currentSignals.length} signals');
              }
            } catch (e) {
              print('Scanner: Error parsing signals JSON: $e');
            }
          } else {
            print('Scanner: Response is not a JSON array: $response');
          }
        } else {
          print('Scanner: Empty response');
        }
      } else {
        // Get spectrum data (using scan command for now)
        String command = 'scan -100 $_selectedModule';
        print('Scanner: Sending command: $command');
        String response = await bleProvider.sendCommandSync(command);
        print('Scanner: Received response: $response');
        
        if (response.isNotEmpty) {
          // Проверяем, что это JSON объект
          if (response.startsWith('{') && response.endsWith('}')) {
            try {
              Map<String, dynamic> spectrumJson = jsonDecode(response);
              Map<String, double> newSpectrum = {};
              
              spectrumJson.forEach((key, value) {
                newSpectrum[key] = double.parse(value.toString());
              });
              
              print('Scanner: Parsed spectrum with ${newSpectrum.length} frequencies');
              
              if (mounted) {
                setState(() {
                  _frequencySpectrum = newSpectrum;
                });
                print('Scanner: UI updated with spectrum data');
              }
            } catch (e) {
              print('Scanner: Error parsing spectrum JSON: $e');
            }
          } else {
            print('Scanner: Response is not a JSON object: $response');
          }
        } else {
          print('Scanner: Empty response');
        }
      }
    } catch (e) {
      // Игнорируем ошибки для плавной работы
      print('Error updating scan data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        return Scaffold(
          body: Column(
            children: [
              // Компактный заголовок
              Container(
                height: 48, // Compact height
                color: Theme.of(context).colorScheme.inversePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.radar, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scanner',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: _clearSignals,
                      tooltip: 'Очистить список',
                    ),
                    IconButton(
                      icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                      onPressed: _isScanning ? _stopScanning : _startScanning,
                      tooltip: _isScanning ? 'Остановить' : 'Запустить',
                    ),
                  ],
                ),
              ),
              // Контент
              Expanded(
                child: Column(
                  children: [
                    // Панель управления
                    _buildControlPanel(),
                    
                    // Переключатель режимов
                    _buildModeSwitch(),
                    
                    // Контент в зависимости от режима
                    Expanded(
                      child: _isListMode ? _buildListView(bleProvider) : _buildSpectrumView(),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
      },
    );
  }

  // Панель управления
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          // Выбор модуля
          Row(
            children: [
              const Text('Модуль:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              ToggleButtons(
                isSelected: [_selectedModule == 0, _selectedModule == 1],
                onPressed: (index) {
                  if (!_isScanning) {
                    setState(() {
                      _selectedModule = index;
                    });
                  }
                },
                children: const [
                  Text('Модуль 0'),
                  Text('Модуль 1'),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Порог RSSI (только для режима списка)
          if (_isListMode) ...[
            Row(
              children: [
                const Text('Порог RSSI:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _rssiThreshold,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${_rssiThreshold.toInt()} dBm',
                    onChanged: _isScanning ? null : (value) {
                      setState(() {
                        _rssiThreshold = value;
                      });
                    },
                  ),
                ),
                Text('${_rssiThreshold.toInt()} dBm'),
              ],
            ),
          ],
          
          // Статус сканирования
          Row(
            children: [
              Icon(
                _isScanning ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _isScanning ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                _isScanning ? 'Сканирование активно' : 'Сканирование остановлено',
                style: TextStyle(
                  color: _isScanning ? Colors.green : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Переключатель режимов
  Widget _buildModeSwitch() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.grey[200],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isScanning) {
                  setState(() {
                    _isListMode = true;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: _isListMode ? Colors.deepPurple : Colors.transparent,
                ),
                child: Text(
                  'Список сигналов',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isListMode ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isScanning) {
                  setState(() {
                    _isListMode = false;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: !_isListMode ? Colors.deepPurple : Colors.transparent,
                ),
                child: Text(
                  'Спектрограмма',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isListMode ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Режим списка сигналов
  Widget _buildListView(BleProvider bleProvider) {
    if (bleProvider.detectedSignals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signal_cellular_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning ? 'Поиск сигналов...' : 'Нажмите "Запуск" для начала сканирования',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bleProvider.detectedSignals.length,
      itemBuilder: (context, index) {
        final signal = bleProvider.detectedSignals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRssiColor(signal.rssi),
              child: Text(
                '${signal.module}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              signal.frequencyFormatted,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RSSI: ${signal.rssiFormatted}'),
                Text('Время: ${signal.timeFormatted}'),
              ],
            ),
            trailing: Icon(
              _getSignalStrengthIcon(signal.rssi),
              color: _getRssiColor(signal.rssi),
            ),
          ),
        );
      },
    );
  }

  // Режим спектрограммы
  Widget _buildSpectrumView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Заголовок
          Text(
            'Спектрограмма сигналов',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Эквалайзер
          Expanded(
            child: _buildSpectrumEqualizer(),
          ),
          
          // Легенда
          _buildSpectrumLegend(),
        ],
      ),
    );
  }

  // Эквалайзер спектрограммы
  Widget _buildSpectrumEqualizer() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Ось Y (RSSI)
            Expanded(
              child: Row(
                children: [
                  // Подписи оси Y
                  SizedBox(
                    width: 40,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('100', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        Text('50', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        Text('0', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        Text('-50', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        Text('-100', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  
                  // Эквалайзер
                  Expanded(
                    child: _buildSpectrumBars(),
                  ),
                ],
              ),
            ),
            
            // Ось X (Частоты)
            const SizedBox(height: 8),
            _buildFrequencyLabels(),
          ],
        ),
      ),
    );
  }

  // Столбцы эквалайзера
  Widget _buildSpectrumBars() {
    return AnimatedBuilder(
      animation: _spectrumAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _scanFrequencies.map((frequency) {
            double rssi = _frequencySpectrum[frequency.toString()] ?? -100.0;
            double height = ((rssi + 100) / 200) * 0.8; // Нормализация от -100 до +100
            
            return Container(
              width: 12,
              height: height * 200, // Максимальная высота 200px
              decoration: BoxDecoration(
                color: _getRssiColor(rssi.toInt()),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      _getRssiColor(rssi.toInt()).withOpacity(0.8),
                      _getRssiColor(rssi.toInt()),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Подписи частот
  Widget _buildFrequencyLabels() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _scanFrequencies.map((frequency) {
        return SizedBox(
          width: 12,
          child: Text(
            frequency.toStringAsFixed(0),
            style: TextStyle(fontSize: 8, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  // Легенда спектрограммы
  Widget _buildSpectrumLegend() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Colors.red, 'Сильный сигнал'),
          _buildLegendItem(Colors.orange, 'Средний сигнал'),
          _buildLegendItem(Colors.green, 'Слабый сигнал'),
          _buildLegendItem(Colors.grey, 'Нет сигнала'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Получение цвета по RSSI
  Color _getRssiColor(int rssi) {
    if (rssi >= -30) return Colors.red;
    if (rssi >= -50) return Colors.orange;
    if (rssi >= -70) return Colors.yellow;
    if (rssi >= -90) return Colors.green;
    return Colors.grey;
  }

  // Получение иконки силы сигнала
  IconData _getSignalStrengthIcon(int rssi) {
    if (rssi >= -30) return Icons.signal_cellular_4_bar;
    if (rssi >= -50) return Icons.network_cell;
    if (rssi >= -70) return Icons.signal_cellular_alt_2_bar;
    if (rssi >= -90) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_off;
  }
}
