import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../services/signal_processing/signal_data.dart';
import '../services/cc1101/cc1101_values.dart';
import '../services/cc1101/cc1101_calculator.dart';
import '../widgets/record_screen_widgets.dart';
import '../widgets/file_list_widget.dart';
import 'file_viewer_screen.dart';

/// Экран записи сигналов
/// Позволяет настраивать параметры CC1101 и записывать сигналы
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _tabControllerInitialized = false;
  int _selectedModule = 0;
  
  // Конфигурации для каждого модуля
  final List<RecordConfig> _recordConfigs = [];
  
  // Контроллеры для полей ввода
  final List<TextEditingController> _frequencyControllers = [];
  final List<TextEditingController> _dataRateControllers = [];
  final List<TextEditingController> _deviationControllers = [];
  final List<TextEditingController> _bandwidthControllers = [];
  
  // Локальное состояние для записанных файлов (не зависит от BleProvider)
  final List<dynamic> _recordedFiles = [];
  
  // Файлы текущей сессии записи
  final List<String> _currentSessionFiles = [];
  
  // Флаги для отслеживания изменений
  final List<bool> _configsChanged = [];
  
  // Состояние развернутости Advanced Mode для каждого модуля
  final List<bool> _isAdvancedExpanded = [];
  
  // Время последнего обнаружения частоты для каждого модуля
  final Map<int, DateTime> _lastFrequencyDetectionTime = {};
  
  @override
  void initState() {
    super.initState();
    _initializeConfigs();
    
    // Слушаем изменения в recordedRuntimeFiles для отслеживания новых файлов
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      bleProvider.addListener(_onRecordedFilesChanged);
    });
  }
  
  void _onRecordedFilesChanged() {
    if (!mounted) return; // Проверяем, что виджет еще активен
    
    print('_onRecordedFilesChanged called');
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final runtimeFiles = bleProvider.recordedRuntimeFiles ?? [];
    print('Runtime files: $runtimeFiles');
    
    // Добавляем новые файлы в локальный список записанных файлов
    for (final file in runtimeFiles) {
      // Извлекаем имя файла из объекта
      String fileName;
      if (file is Map<String, dynamic> && file.containsKey('filename')) {
        fileName = file['filename'].toString();
      } else {
        fileName = file.toString();
      }
      
      print('Processing file: $fileName');
      if (!_currentSessionFiles.contains(fileName)) {
        print('Adding new file to session: $fileName');
        setState(() {
          _currentSessionFiles.add(fileName);
          
          // Создаем объект файла для локального списка
          final fileObject = _createFileObject(fileName);
          if (!_recordedFiles.any((f) => f.name == fileName)) {
            _recordedFiles.add(fileObject);
            print('Added to recorded files list: $fileName');
          }
        });
      }
    }
    print('Current recorded files count: ${_recordedFiles.length}');
  }
  
  void _clearCurrentSession() {
    setState(() {
      _currentSessionFiles.clear();
      _recordedFiles.clear();
    });
  }

  // Создает объект файла для локального списка
  dynamic _createFileObject(String fileName, {DateTime? dateCreated}) {
    return _FileObject(
      name: fileName,
      size: 0, // Размер будет обновлен при получении информации о файле
      isDirectory: false,
      isFile: true,
      dateCreated: dateCreated,
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    
    // Удаляем слушатель
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    bleProvider.removeListener(_onRecordedFilesChanged);
    
    super.dispose();
  }
  
  void _initializeConfigs() {
    // Инициализируем конфигурации для модулей
    for (int i = 0; i < 2; i++) { // Предполагаем 2 модуля CC1101
       _recordConfigs.add(RecordConfig(
         frequency: 433.92,
         module: i,
         advancedMode: false,
         preset: 'Ook270',
         modulation: 'ASK/OOK',
       ));
      
      _configsChanged.add(false);
      _isAdvancedExpanded.add(false);
      
      // Создаем контроллеры для полей ввода
      _frequencyControllers.add(TextEditingController(text: '433.92'));
      _dataRateControllers.add(TextEditingController());
      _deviationControllers.add(TextEditingController());
      _bandwidthControllers.add(TextEditingController());
    }
    
    // Обновляем количество табов на основе количества модулей
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _tabController = TabController(length: _recordConfigs.length, vsync: this);
          _tabControllerInitialized = true;
          
          // Добавляем слушатель анимации для отслеживания прогресса свайпа
          _tabController.animation?.addListener(() {
            if (!mounted) return;
            
            final progress = _tabController.animation!.value;
            final currentIndex = progress.round();
            
            if (currentIndex != _selectedModule) {
              setState(() {
                _selectedModule = currentIndex;
              });
              print('TabController animation: Progress ${progress.toStringAsFixed(2)}, Module $currentIndex');
            }
          });
        });
      }
    });
  }
  
  void _disposeControllers() {
    for (final controller in _frequencyControllers) {
      controller.dispose();
    }
    for (final controller in _dataRateControllers) {
      controller.dispose();
    }
    for (final controller in _deviationControllers) {
      controller.dispose();
    }
    for (final controller in _bandwidthControllers) {
      controller.dispose();
    }
  }
  
  void _updateSelectedModule(int index) {
    // Теперь обновление происходит через слушатель TabController
    // Оставляем метод для совместимости, но не вызываем setState
    print('_updateSelectedModule: Changed to module $index (handled by TabController listener)');
  }
  
  void _updateConfig(int moduleIndex, RecordConfig newConfig) {
    if (mounted) {
      setState(() {
        _recordConfigs[moduleIndex] = newConfig;
        _configsChanged[moduleIndex] = true;
      });
    }
  }

  void _startFrequencySearch(int moduleIndex, BleProvider bleProvider) async {
    try {
      await bleProvider.startFrequencySearch(moduleIndex, minRssi: -65);
      _showSuccessSnackBar('Frequency search started for Module ${moduleIndex + 1}');
      
      // Listen for detected signals and update frequency
      _listenForDetectedFrequency(moduleIndex, bleProvider);
    } catch (e) {
      _showErrorSnackBar('Failed to start frequency search: $e');
    }
  }

  void _listenForDetectedFrequency(int moduleIndex, BleProvider bleProvider) {
    // This will be called when a signal is detected
    // The frequency will be automatically updated in the dropdown
    // when the detectedSignals list changes
  }
  
  /// Находит ближайшую частоту из списка CC1101Values.frequencies
  /// Возвращает строковое значение частоты из списка или null
  String? _findClosestFrequencyString(double detectedFreq) {
    if (CC1101Values.frequencies.isEmpty) return null;
    
    String? closest;
    double minDifference = double.infinity;
    
    for (final freqString in CC1101Values.frequencies) {
      final freq = double.tryParse(freqString);
      if (freq == null) continue;
      
      final difference = (freq - detectedFreq).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closest = freqString;
      }
    }
    
    return closest;
  }

  void _stopFrequencySearch(int moduleIndex, BleProvider bleProvider) async {
    try {
      // Send idle command to stop frequency search
      await bleProvider.sendIdleCommand(moduleIndex);
      _showSuccessSnackBar('Frequency search stopped for Module ${moduleIndex + 1}');
    } catch (e) {
      _showErrorSnackBar('Failed to stop frequency search: $e');
    }
  }
  
  void _startRecording(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    if (!bleProvider.isConnected) {
      _showErrorDialog('Ошибка', 'Устройство не подключено');
      return;
    }
    
    // Проверяем доступность модуля
    if (!bleProvider.isModuleAvailable(moduleIndex)) {
      final status = bleProvider.getModuleStatus(moduleIndex);
      _showErrorDialog(
        'Модуль занят', 
        'Модуль ${moduleIndex + 1} сейчас в режиме "$status".\nДождитесь завершения текущей операции или переведите модуль в режим Idle.'
      );
      return;
    }
    
    final config = _recordConfigs[moduleIndex];
    final errors = bleProvider.validateRecordConfig(config);
    
    if (errors.isNotEmpty) {
      _showErrorDialog('Ошибка валидации', errors.join('\n'));
      return;
    }
    
     try {
       // Отправляем бинарную команду записи через Enhanced Protocol
       // В Advanced Mode передаем все параметры, в Simple Mode - только preset
       await bleProvider.sendRecordCommand(
         frequency: config.frequency,
         module: moduleIndex,
         preset: config.advancedMode ? null : config.preset,
         modulation: config.advancedMode ? _getModulationValue(config.modulation) : null,
         deviation: config.advancedMode ? config.deviation : null,
         rxBandwidth: config.advancedMode ? config.rxBandwidth : null,
         dataRate: config.advancedMode ? config.dataRate : null,
       );
       
       // Запрашиваем актуальное состояние устройства
       await bleProvider.sendGetStateCommand();
       
       _showSuccessSnackBar('Запись начата на модуле ${moduleIndex + 1}');
     } catch (e) {
       _showErrorDialog('Ошибка записи', 'Не удалось начать запись: $e');
     }
  }
  
  void _stopRecording(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    try {
      await bleProvider.sendIdleCommand(moduleIndex);
      
      // Запрашиваем актуальное состояние устройства
      await bleProvider.sendGetStateCommand();
      
      _showSuccessSnackBar('Запись остановлена на модуле ${moduleIndex + 1}');
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось остановить запись: $e');
    }
  }

  /// Преобразует строку модуляции в числовое значение для ESP32
  int? _getModulationValue(String? modulation) {
    if (modulation == null) return null;
    
    switch (modulation.toLowerCase()) {
      case 'ask/ook':
      case 'ook':
        return 2; // MODULATION_ASK_OOK
      case '2-fsk':
      case '2fsk':
        return 0; // MODULATION_2_FSK
      default:
        return null;
    }
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSettingsOverlay() {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isRecording = bleProvider.isModuleRecording(_selectedModule);
        
        // Отладочная информация
        print('_buildRecordSettingsOverlay: isRecording=$isRecording, _selectedModule=$_selectedModule');
        
        // Показываем оверлей только при записи
        if (!isRecording) {
          return const SizedBox.shrink();
        }
        
        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Первая строка: иконка и текст "Recording" в одну строку
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Иконка записи
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                        const SizedBox(width: 12),
                        // Текст "Recording"
                    Text(
                      'Recording',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Вторая строка: параметры с Wrap
                    _buildStatusWidgetOverlay(bleProvider),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusWidgetOverlay(BleProvider bleProvider) {
    // Получаем данные модуля из cc1101Modules
    final modules = bleProvider.cc1101Modules;
    if (modules == null || _selectedModule >= modules.length) {
      return const SizedBox.shrink();
    }
    
    final module = modules[_selectedModule];
    final settings = module['settings'] ?? '';
    
    // Парсим настройки модуля
    CC1101Config? config;
    try {
      if (settings.isNotEmpty) {
        config = parseSettingsFromString(settings);
      }
    } catch (e) {
      // Если не удалось распарсить, показываем ошибку
    }
    
    if (config == null) {
      return Text(
        'Settings not available',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
      );
    }
    
    // Компактное расположение всех параметров
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Первая строка: Частота и Модуляция
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildInfoItem(
              context,
              Icons.signal_cellular_alt,
              '${config.frequency.toStringAsFixed(1)} MHz',
              'Freq',
            ),
            const SizedBox(width: 8),
            _buildInfoItem(
              context,
              Icons.tune,
              config.modulationName,
              'Mod',
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Вторая строка: Rate, BW, Dev (с Wrap для переноса)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildInfoItem(
              context,
              Icons.speed,
              '${(config.dataRate / 1000).toStringAsFixed(1)} kbps',
              'Rate',
            ),
            _buildInfoItem(
              context,
              Icons.signal_cellular_4_bar,
              '${(config.bandwidth / 1000).toStringAsFixed(1)} kHz',
              'BW',
        ),
            // Deviation для FM модуляций (2-FSK, GFSK, 4-FSK) - показываем всегда для FSK модуляций
            if (config.modulationName.contains('FSK') || config.modulation == 0 || config.modulation == 1)
          _buildInfoItem(
            context,
            Icons.tune,
            '${(config.deviation / 1000).toStringAsFixed(2)} kHz',
                'Dev',
          ),
        ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(width: 3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
  
  void _showSuccessSnackBar(String message) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.showSuccess(message);
  }

  void _showErrorSnackBar(String message) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // Компактный TabBar
          Container(
            height: 48, // Compact height
              color: Theme.of(context).colorScheme.surface,
              child: _tabControllerInitialized ? TabBar(
              controller: _tabController,
                onTap: (index) {
                // Обновляем _selectedModule при нажатии на таб
                // Используем анимацию для плавного перехода
                setState(() {
                  _selectedModule = index;
                });
                print('Tab tap: Changed to module $index');
              },
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              tabs: _recordConfigs.asMap().entries.map((entry) {
                final index = entry.key;
                  return Consumer<BleProvider>(
                    builder: (context, bleProvider, child) {
                      final isAvailable = bleProvider.isModuleAvailable(index);
                      final status = bleProvider.getModuleStatus(index);
                      
                return Tab(
                        icon: Stack(
                          children: [
                            Icon(
                              Icons.signal_cellular_alt, 
                              size: 18,
                              color: isAvailable ? null : Colors.grey,
                            ),
                            if (!isAvailable)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                  text: 'Module ${index + 1}',
                  iconMargin: const EdgeInsets.only(bottom: 2),
                      );
                    },
                );
              }).toList(),
              ) : const Center(child: CircularProgressIndicator()),
            ),
                 // Контент модулей
          Expanded(
                   child: _tabControllerInitialized ? TabBarView(
              controller: _tabController,
              children: _recordConfigs.asMap().entries.map((entry) {
                final index = entry.key;
                final config = entry.value;
                
                return _buildModuleTab(index, config);
              }).toList(),
                   ) : const Center(child: CircularProgressIndicator()),
            ),
            
            // Кнопка записи прилеплена к низу с анимацией
            _buildRecordingButton(),
        ],
        ),
      ),
    );
  }
  
  Widget _buildModuleTab(int moduleIndex, RecordConfig config) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isRecording = bleProvider.isModuleRecording(moduleIndex);
        print('RecordScreen: Module $moduleIndex, isRecording=$isRecording');
        print('RecordScreen: Current selected module: $_selectedModule');
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Настройки записи с оверлеем записи
              Stack(
                children: [
              _buildRecordSettings(moduleIndex, config, isRecording),
                  // Оверлей записи только на область настроек (всегда показываем для тестирования)
                  _buildRecordSettingsOverlay(),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Список файлов для этого модуля
              _buildModuleFilesList(moduleIndex),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordingButton() {
    // Определяем состояние кнопки вне Consumer для правильной работы анимации
    final isRecording = Provider.of<BleProvider>(context, listen: true).isModuleRecording(_selectedModule);
    final isAvailable = Provider.of<BleProvider>(context, listen: true).isModuleAvailable(_selectedModule);
    final config = _recordConfigs[_selectedModule];
    
    print('_buildRecordingButton: Selected module: $_selectedModule, isRecording: $isRecording, isAvailable: $isAvailable');
    
    // Определяем состояние кнопки
    bool isEnabled = true;
    String buttonText = 'Start Recording';
    IconData buttonIcon = Icons.fiber_manual_record;
    Color buttonColor = Colors.red;
    
    if (isRecording) {
      buttonText = 'Stop Recording';
      buttonIcon = Icons.stop;
      buttonColor = Colors.orange;
    } else if (!isAvailable) {
      isEnabled = false;
      buttonText = 'Module Busy';
      buttonIcon = Icons.block;
      buttonColor = Colors.grey;
    }
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
      child: Container(
        key: ValueKey('recording_button_$_selectedModule'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isEnabled 
                ? (isRecording 
                    ? () => _stopRecording(_selectedModule)
                    : () => _startRecording(_selectedModule))
                : null,
              icon: Icon(buttonIcon),
              label: Text('$buttonText (Module ${_selectedModule + 1})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedModeToggle(int moduleIndex, RecordConfig config) {
    // Полоска всегда видна, чтобы показать возможность расширения
    return GestureDetector(
      onTap: () {
        setState(() {
          if (!config.advancedMode) {
            // Если advancedMode выключен, включаем его и разворачиваем
            _updateConfig(moduleIndex, config.copyWith(advancedMode: true));
            _isAdvancedExpanded[moduleIndex] = true;
          } else {
            // Если включен, просто сворачиваем/разворачиваем
            _isAdvancedExpanded[moduleIndex] = !_isAdvancedExpanded[moduleIndex];
          }
        });
      },
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              (config.advancedMode && _isAdvancedExpanded[moduleIndex]) 
                  ? Icons.keyboard_arrow_up 
                  : Icons.keyboard_arrow_down,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              (config.advancedMode && _isAdvancedExpanded[moduleIndex]) ? 'presets' : 'advanced',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
            ],
          ),
      ),
    );
  }
  
  Widget _buildModuleStatus(int moduleIndex, BleProvider bleProvider, RecordConfig config) {
    final module = bleProvider.cc1101Modules?[moduleIndex];
    final mode = module?['mode'] ?? 'Unknown';
    final isConnected = bleProvider.isConnected;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (mode.toLowerCase()) {
      case 'idle':
        statusColor = Colors.green;
        statusIcon = Icons.pause_circle;
        break;
      case 'recordsignal':
        statusColor = Colors.orange;
        statusIcon = Icons.fiber_manual_record;
        break;
      case 'detectsignal':
        statusColor = Colors.blue;
        statusIcon = Icons.radar;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Module ${moduleIndex + 1}: $mode',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                  if (mode != 'Idle' && config != null) ...[
                    const SizedBox(height: 2),
                  Text(
                      '${config.frequency}MHz, ${config.dataRate}kbps',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecordSettings(int moduleIndex, RecordConfig config, bool isRecording) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
             // Частота с кнопкой поиска
             Row(
               children: [
                 Expanded(
                   child: Consumer<BleProvider>(
                      builder: (context, bleProvider, child) {
                       // Find current frequency string from list, or use config frequency
                       String? currentFrequencyString = _findClosestFrequencyString(config.frequency);
                       String currentFrequency = currentFrequencyString ?? config.frequency.toStringAsFixed(2);
                       
                       // Get signals for this module, sorted by timestamp (newest first)
                       final moduleSignals = bleProvider.detectedSignals
                           .where((signal) => signal.module == moduleIndex)
                           .where((signal) => signal.timestamp.isAfter(DateTime.now().subtract(const Duration(seconds: 30))))
                           .toList();
                       
                       // Sort by timestamp (newest first) to ensure we get the latest
                       moduleSignals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                       
                       if (moduleSignals.isNotEmpty) {
                         // Use the most recent detected frequency (first after sort)
                         final latestSignal = moduleSignals.first;
                         final detectedFreq = double.tryParse(latestSignal.frequency);
                         if (detectedFreq != null && detectedFreq > 0) {
                           // Find closest frequency from the list
                           final closestFreqString = _findClosestFrequencyString(detectedFreq);
                           if (closestFreqString != null) {
                             currentFrequency = closestFreqString;
                             final closestFreq = double.parse(closestFreqString);
                             
                             // Update config if frequency changed
                             if ((closestFreq - config.frequency).abs() > 0.001) {
                               // Сохраняем время обнаружения частоты только при новом обнаружении
                               _lastFrequencyDetectionTime[moduleIndex] = DateTime.now();
                               
                               // Устанавливаем таймер для скрытия иконки через 3 секунды
                               Future.delayed(const Duration(seconds: 3), () {
                                 if (mounted) {
                                   setState(() {
                                     // Обновляем UI, чтобы скрыть иконку
                                   });
                                 }
                               });
                               
                             // Use a small delay to ensure state is updated
                             Future.microtask(() {
                               if (mounted) {
                                   _updateConfig(moduleIndex, config.copyWith(frequency: closestFreq));
                                   print('Updated frequency to ${closestFreq}MHz for module $moduleIndex');
                                 }
                               });
                             }
                           }
                         }
                       }
                       
                       // Проверяем, прошло ли 3 секунды с момента обнаружения частоты
                       bool shouldShowIcon = false;
                       if (moduleSignals.isNotEmpty) {
                         final lastDetectionTime = _lastFrequencyDetectionTime[moduleIndex];
                         if (lastDetectionTime != null) {
                           final secondsSinceDetection = DateTime.now().difference(lastDetectionTime).inSeconds;
                           shouldShowIcon = secondsSinceDetection < 3;
                         } else {
                           // Если времени нет, но есть сигналы, показываем иконку
                           shouldShowIcon = true;
                           _lastFrequencyDetectionTime[moduleIndex] = DateTime.now();
                         }
                       }
                       
                       // Ensure currentFrequency is in the list, otherwise use closest
                       if (!CC1101Values.frequencies.contains(currentFrequency)) {
                         final closest = _findClosestFrequencyString(config.frequency);
                         if (closest != null) {
                           currentFrequency = closest;
                         } else if (CC1101Values.frequencies.isNotEmpty) {
                           currentFrequency = CC1101Values.frequencies.first;
                           }
                         }
                       
                       // Use key based on latest signal to force rebuild on new detections
                       final latestSignalKey = moduleSignals.isNotEmpty 
                           ? '${moduleSignals.first.frequency}_${moduleSignals.first.timestamp.millisecondsSinceEpoch}'
                           : '${config.frequency}';
                       
                       return DropdownButtonFormField<String>(
                         key: ValueKey('freq_dropdown_${moduleIndex}_$latestSignalKey'),
                         value: currentFrequency,
                         onChanged: (!isRecording && !bleProvider.isModuleFrequencySearching(moduleIndex)) ? (value) {
                 if (value != null) {
                             final frequency = double.tryParse(value);
                             if (frequency != null) {
                               _updateConfig(moduleIndex, config.copyWith(frequency: frequency));
                             }
                 }
               } : null,
                         decoration: InputDecoration(
                           labelText: 'Frequency (MHz)',
                           border: const OutlineInputBorder(),
                           prefixIcon: const Icon(Icons.radio),
                           suffixIcon: shouldShowIcon ? 
                             Icon(
                               Icons.check_circle,
                               color: Colors.green,
                               size: 16,
                             ) : null,
                           isDense: true,
                           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         ),
                         isDense: true,
                         items: CC1101Values.frequencies.map((freq) {
                           return DropdownMenuItem<String>(
                             value: freq,
                             child: Text(freq),
                           );
                         }).toList(),
                       );
                     },
                   ),
                 ),
                 const SizedBox(width: 8),
                 Consumer<BleProvider>(
                   builder: (context, bleProvider, child) {
                     final isSearching = bleProvider.isModuleFrequencySearching(moduleIndex);
                     return IconButton(
                       onPressed: isSearching ? () => _stopFrequencySearch(moduleIndex, bleProvider) : () => _startFrequencySearch(moduleIndex, bleProvider),
                       icon: Icon(
                         isSearching ? Icons.stop : Icons.search,
                         color: isSearching ? Colors.red : null,
                       ),
                       tooltip: isSearching ? 'Stop frequency search' : 'Search for frequency',
                       style: IconButton.styleFrom(
                         backgroundColor: isSearching ? Colors.red.withOpacity(0.1) : null,
               ),
                     );
                   },
                 ),
               ],
             ),
            
            const SizedBox(height: 12),
            
            // Настройки в зависимости от режима
            if (config.advancedMode && _isAdvancedExpanded[moduleIndex]) ...[
              _buildAdvancedSettings(moduleIndex, config, isRecording),
            ] else ...[
              _buildSimpleSettings(moduleIndex, config, isRecording),
            ],
            
            // Узкая полоска с кнопкой "advanced" внизу формы
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildAdvancedModeToggle(moduleIndex, config),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSimpleSettings(int moduleIndex, RecordConfig config, bool isRecording) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isFrequencySearching = bleProvider.isModuleFrequencySearching(moduleIndex);
    return PresetSelector(
      value: config.preset,
          onChanged: (isRecording || isFrequencySearching) ? null : (value) {
        if (value != null) {
          _updateConfig(moduleIndex, config.copyWith(preset: value));
        }
          },
        );
      },
    );
  }
  
  Widget _buildAdvancedSettings(int moduleIndex, RecordConfig config, bool isRecording) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isFrequencySearching = bleProvider.isModuleFrequencySearching(moduleIndex);
    return Column(
      children: [
        // Полоса пропускания
        BandwidthSelector(
          controller: _bandwidthControllers[moduleIndex],
          value: config.rxBandwidth,
              onChanged: (isRecording || isFrequencySearching) ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(rxBandwidth: value));
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Скорость передачи данных
        DataRateInputField(
          controller: _dataRateControllers[moduleIndex],
          value: config.dataRate,
              onChanged: (isRecording || isFrequencySearching) ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(dataRate: value));
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Тип модуляции
        ModulationSelector(
          value: config.modulation,
              onChanged: (isRecording || isFrequencySearching) ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(modulation: value));
            }
          },
        ),
        
        // Девиация (только для FM модуляции)
        if (config.modulation == '2-FSK') ...[
          const SizedBox(height: 16),
          DeviationInputField(
            controller: _deviationControllers[moduleIndex],
            value: config.deviation,
                onChanged: (isRecording || isFrequencySearching) ? null : (value) {
              if (value != null) {
                _updateConfig(moduleIndex, config.copyWith(deviation: value));
              }
            },
          ),
        ],
      ],
    );
      },
    );
  }
  
  Widget _buildModuleFilesList(int moduleIndex) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        // Обновляем локальный список при изменении recordedRuntimeFiles
        final runtimeFiles = bleProvider.recordedRuntimeFiles ?? [];
        print('_buildModuleFilesList: Module $moduleIndex, runtimeFiles count: ${runtimeFiles.length}');
        
        // Фильтруем файлы по модулю
        final moduleFiles = <dynamic>[];
        
        for (final file in runtimeFiles) {
          // Извлекаем имя файла из объекта
          String fileName;
          DateTime? dateCreated;
          
          if (file is Map<String, dynamic>) {
            if (file.containsKey('filename')) {
            fileName = file['filename'].toString();
            } else {
              fileName = file.toString();
            }
            
            // Извлекаем дату создания, если она есть
            if (file.containsKey('date')) {
              try {
                if (file['date'] is String) {
                  dateCreated = DateTime.tryParse(file['date']);
                }
              } catch (e) {
                print('Error parsing date for file $fileName: $e');
              }
            }
          } else {
            fileName = file.toString();
          }
          
          print('_buildModuleFilesList: Processing file: $fileName for module $moduleIndex');
          
          // Проверяем, принадлежит ли файл этому модулю
          if (_isFileFromModule(fileName, moduleIndex)) {
            print('_buildModuleFilesList: File $fileName belongs to module $moduleIndex');
            final fileObject = _createFileObject(fileName, dateCreated: dateCreated);
            if (!moduleFiles.any((f) => f.name == fileName)) {
              moduleFiles.add(fileObject);
              print('_buildModuleFilesList: Added file $fileName to module $moduleIndex list');
            }
          } else {
            print('_buildModuleFilesList: File $fileName does NOT belong to module $moduleIndex');
          }
        }
        
        print('_buildModuleFilesList: Module $moduleIndex has ${moduleFiles.length} files');
        
        // Отладочная информация о файлах
        for (int i = 0; i < moduleFiles.length; i++) {
          final file = moduleFiles[i];
          print('_buildModuleFilesList: File $i: name="${file.name}", size=${file.size}, isDirectory=${file.isDirectory}');
        }
        
        return SizedBox(
          height: 200,
          child: FileListWidget(
            files: moduleFiles,
            mode: FileListMode.local,
               title: 'Module ${moduleIndex + 1} Signals Recorded (${moduleFiles.length})',
            showHeader: true,
            showActions: true,
            filterExtension: 'sub',
            onRefresh: null, // Отключаем pull-to-refresh
            onFileSelected: (file) => _openFileViewer(file),
            onFileAction: (file, action) => _handleRecordedFileAction(file, action),
          ),
        );
      },
    );
  }

  /// Определяет, принадлежит ли файл указанному модулю по имени файла
  /// Формат имени: m{module}_{frequency}_{modulation}_{bandwidth}_{random}.sub
  bool _isFileFromModule(String fileName, int moduleIndex) {
    print('_isFileFromModule: Checking file "$fileName" for module $moduleIndex');
    
    // Проверяем формат имени файла: m{module}_...
    final regex = RegExp(r'^m(\d+)_');
    final match = regex.firstMatch(fileName);
    
    if (match != null) {
      final fileModule = int.tryParse(match.group(1) ?? '');
      print('_isFileFromModule: File module: $fileModule, requested module: $moduleIndex');
      return fileModule == moduleIndex;
    }
    
    print('_isFileFromModule: File "$fileName" does not match pattern m{module}_...');
    return false;
  }
  
  Widget _buildRecordedFilesList() {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        // Обновляем локальный список при изменении recordedRuntimeFiles
        final runtimeFiles = bleProvider.recordedRuntimeFiles ?? [];
        bool hasNewFiles = false;
        
        for (final file in runtimeFiles) {
          // Извлекаем имя файла из объекта
          String fileName;
          DateTime? dateCreated;
          
          if (file is Map<String, dynamic>) {
            if (file.containsKey('filename')) {
            fileName = file['filename'].toString();
            } else {
              fileName = file.toString();
            }
            
            // Извлекаем дату создания, если она есть
            if (file.containsKey('date')) {
              try {
                if (file['date'] is String) {
                  dateCreated = DateTime.tryParse(file['date']);
                }
              } catch (e) {
                print('Error parsing date for file $fileName: $e');
              }
            }
          } else {
            fileName = file.toString();
          }
          
          if (!_currentSessionFiles.contains(fileName)) {
            _currentSessionFiles.add(fileName);
            final fileObject = _createFileObject(fileName, dateCreated: dateCreated);
            if (!_recordedFiles.any((f) => f.name == fileName)) {
              _recordedFiles.add(fileObject);
              hasNewFiles = true;
            }
          }
        }
        
        // Если есть новые файлы, обновляем состояние
        if (hasNewFiles) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {});
          });
        }
        
        return SizedBox(
          height: 200,
          child: FileListWidget(
            files: _recordedFiles,
            mode: FileListMode.local,
            title: 'Recorded Files',
            showHeader: true,
            showActions: true,
            filterExtension: 'sub',
            onRefresh: null, // Отключаем pull-to-refresh
            onFileSelected: (file) => _openFileViewer(file),
            onFileAction: (file, action) => _handleRecordedFileAction(file, action),
          ),
        );
      },
    );
  }

  void _playFile(String filename) {
    // TODO: Implement file playback
    _showSuccessSnackBar('Playing file: $filename');
  }

  void _openFileViewer(dynamic file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileViewerScreen(
          fileItem: file,
          filePath: '/DATA/SIGNALS/${file.name}',  // Full path with basePath
        ),
      ),
    );
  }

  void _handleRecordedFileAction(dynamic file, String action) {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    switch (action) {
      case 'transmit':
        _transmitRecordedFile(file.name, bleProvider);
        break;
      case 'save_to_signals':
        _saveToSignalsDirectory(file.name, bleProvider);
        break;
      case 'download':
        // TODO: Implement file download
        _showSuccessSnackBar('Downloading file: ${file.name}');
        break;
      case 'delete':
        _showDeleteConfirmation(file.name, bleProvider);
        break;
    }
  }

  void _transmitRecordedFile(String filename, BleProvider bleProvider) async {
    try {
      await bleProvider.transmitFromFile(filename, basePath: '/DATA/SIGNALS');
      _showSuccessSnackBar('Transmitting file: $filename');
    } catch (e) {
      _showErrorSnackBar('Transmission failed: $e');
    }
  }

  void _saveToSignalsDirectory(String filename, BleProvider bleProvider) async {
    // Показываем диалог для выбора имени файла
    final TextEditingController nameController = TextEditingController();
    
    // Предлагаем имя по умолчанию (убираем префикс модуля и расширение)
    String defaultName = filename;
    if (defaultName.startsWith('m') && defaultName.contains('_')) {
      // Убираем префикс модуля (m0_, m1_, etc.)
      final parts = defaultName.split('_');
      if (parts.length > 1) {
        defaultName = parts.sublist(1).join('_');
      }
    }
    // Убираем расширение .sub
    if (defaultName.endsWith('.sub')) {
      defaultName = defaultName.substring(0, defaultName.length - 4);
    }
    nameController.text = defaultName;
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Signal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter a name for the signal:'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Signal Name',
                  hintText: 'Enter signal name...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop(value.trim());
                  }
                },
            ),
          ],
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop(name);
                }
              },
              child: const Text('Save'),
          ),
      ],
    );
      },
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        // Добавляем расширение .sub если его нет
        String targetName = result;
        if (!targetName.endsWith('.sub')) {
          targetName += '.sub';
        }
        
        // Определяем полный путь к исходному файлу
        String sourcePath = '/DATA/SIGNALS/$filename';
        
        // Сохраняем с выбранным именем в директорию RECORDS (pathType = 0)
        await bleProvider.saveFileToSignalsWithName(sourcePath, targetName, pathType: 0);
        _showSuccessSnackBar('Signal saved as: $targetName');
      } catch (e) {
        _showErrorSnackBar('Failed to save signal: $e');
      }
    }
  }

  void _showDeleteConfirmation(String filename, BleProvider bleProvider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Signal'),
          content: Text('Are you sure you want to delete "$filename"?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
                  ),
                ],
        );
      },
    );
    
    if (result == true) {
      try {
        // Определяем полный путь к файлу
        String fullPath = '/DATA/SIGNALS/$filename';
        
        // Удаляем файл
        await bleProvider.deleteFile(fullPath);
        _showSuccessSnackBar('File deleted: $filename');
        
        // Удаляем файл из локального списка записанных файлов
        bleProvider.removeRecordedFile(filename);
        
        // Обновляем общий список файлов
        await bleProvider.refreshFileList(forceRefresh: true);
      } catch (e) {
        _showErrorSnackBar('Failed to delete file: $e');
      }
    }
  }

  void _handleFileAction(BuildContext context, dynamic file, String action, BleProvider bleProvider) {
    switch (action) {
      case 'transmit':
        _transmitRecordedFile(file.name, bleProvider);
        break;
      case 'download':
        // TODO: Implement file download
        _showSuccessSnackBar('Downloading file: ${file.name}');
        break;
      case 'delete':
        // TODO: Implement file deletion
        _showSuccessSnackBar('Deleting file: ${file.name}');
        break;
    }
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Screen Help'),
        content: const SingleChildScrollView(
          child: Text(
            'This screen allows you to record RF signals using the CC1101 modules.\n\n'
            '• Select a module tab to configure its settings\n'
            '• Choose between Simple and Advanced modes\n'
            '• Simple mode uses presets for quick setup\n'
            '• Advanced mode allows fine-tuning of parameters\n'
            '• Start recording to capture signals\n'
            '• Stop recording when done\n'
            '• Recorded files appear in the list below\n\n'
            'Make sure your device is connected before starting recording.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Простой класс для представления файла в локальном списке
class _FileObject {
  final String name;
  final int size;
  final bool isDirectory;
  final bool isFile;
  final DateTime? dateCreated;

  _FileObject({
    required this.name,
    required this.size,
    required this.isDirectory,
    required this.isFile,
    this.dateCreated,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
