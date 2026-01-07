import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../services/signal_processing/signal_data.dart';
import '../services/cc1101/cc1101_values.dart';
import '../services/cc1101/cc1101_calculator.dart';
import '../widgets/record_screen_widgets.dart';
import '../widgets/file_list_widget.dart';
import '../widgets/transmit_file_dialog.dart';
import '../theme/app_colors.dart';
import 'file_viewer_screen.dart';

/// Тип действия с модулем
enum ModuleAction {
  recording,
  jamming,
}

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
  // Действия для каждого модуля (независимые)
  final List<ModuleAction> _selectedActions = [];
  
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
  
  // Флаг для отслеживания, было ли выполнено автоматическое переключение при открытии
  bool _hasAutoSwitched = false;
  
  BleProvider? _bleProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Сохраняем ссылку на BleProvider когда виджет активен
    if (_bleProvider == null) {
      _bleProvider = Provider.of<BleProvider>(context, listen: false);
      _bleProvider?.addListener(_onRecordedFilesChanged);
      _bleProvider?.addListener(_onModuleStateChanged);
    }
    
    // Проверяем состояние модулей при возврате на экран
    if (_tabControllerInitialized && !_hasAutoSwitched) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndSwitchToActiveModule();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeConfigs();
  }
  
  void _onRecordedFilesChanged() {
    if (!mounted) return; // Проверяем, что виджет еще активен
    
    print('_onRecordedFilesChanged called');
    final runtimeFiles = _bleProvider?.recordedRuntimeFiles ?? [];
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
  
  /// Слушатель изменений состояния модулей
  void _onModuleStateChanged() {
    if (!mounted || !_tabControllerInitialized) return;
    
    // Проверяем, нужно ли переключиться на активный модуль
    // Переключаемся только если текущий модуль не активен, а другой активен
    bool currentModuleActive = false;
    if (_selectedModule < _recordConfigs.length) {
      currentModuleActive = _bleProvider?.isModuleJamming(_selectedModule) == true ||
                           _bleProvider?.isModuleRecording(_selectedModule) == true;
    }
    
    // Если текущий модуль не активен, проверяем другие модули
    if (!currentModuleActive) {
      _checkAndSwitchToActiveModule();
    } else {
      // Обновляем выбранное действие для текущего модуля
      if (_bleProvider?.isModuleJamming(_selectedModule) == true) {
        if (_selectedActions[_selectedModule] != ModuleAction.jamming) {
          setState(() {
            _selectedActions[_selectedModule] = ModuleAction.jamming;
          });
        }
      } else if (_bleProvider?.isModuleRecording(_selectedModule) == true) {
        if (_selectedActions[_selectedModule] != ModuleAction.recording) {
          setState(() {
            _selectedActions[_selectedModule] = ModuleAction.recording;
          });
        }
      }
    }
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
    
    // Удаляем слушатели используя сохраненную ссылку
    _bleProvider?.removeListener(_onRecordedFilesChanged);
    _bleProvider?.removeListener(_onModuleStateChanged);
    _bleProvider = null;
    
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
      _selectedActions.add(ModuleAction.recording); // По умолчанию Recording
      
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
          
          // Проверяем состояние модулей и переключаемся на активный
          _checkAndSwitchToActiveModule();
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
  
  /// Проверяет состояние модулей и переключается на активный (jamming или recording)
  void _checkAndSwitchToActiveModule() {
    if (_bleProvider == null || !_tabControllerInitialized) return;
    
    // Приоритет: jamming > recording
    // Сначала проверяем jamming
    for (int i = 0; i < _recordConfigs.length; i++) {
      if (_bleProvider!.isModuleJamming(i)) {
        print('RecordScreen: Module $i is jamming, switching to module $i and jamming tab');
        setState(() {
          _selectedModule = i;
          _selectedActions[i] = ModuleAction.jamming;
          _tabController.animateTo(i);
          _hasAutoSwitched = true;
        });
        return;
      }
    }
    
    // Затем проверяем recording
    for (int i = 0; i < _recordConfigs.length; i++) {
      if (_bleProvider!.isModuleRecording(i)) {
        print('RecordScreen: Module $i is recording, switching to module $i and recording tab');
        setState(() {
          _selectedModule = i;
          _selectedActions[i] = ModuleAction.recording;
          _tabController.animateTo(i);
          _hasAutoSwitched = true;
        });
        return;
      }
    }
  }
  
  void _updateConfig(int moduleIndex, RecordConfig newConfig) {
    if (mounted) {
      setState(() {
        _recordConfigs[moduleIndex] = newConfig;
        _configsChanged[moduleIndex] = true;
      });
    }
  }

  /// Проверяет, занят ли модуль (записывает, джаммит, передает и т.д.)
  bool _isModuleBusy(int moduleIndex, BleProvider bleProvider) {
    return bleProvider.isModuleRecording(moduleIndex) ||
           bleProvider.isModuleJamming(moduleIndex) ||
           !bleProvider.isModuleAvailable(moduleIndex);
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
      _showSuccessSnackBar(AppLocalizations.of(context)!.frequencySearchStoppedForModule(moduleIndex + 1));
    } catch (e) {
      _showErrorSnackBar('Failed to stop frequency search: $e');
    }
  }
  
  void _startJamming(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    final l10n = AppLocalizations.of(context)!;
    if (!bleProvider.isConnected) {
      _showErrorDialog(l10n.error, l10n.deviceNotConnected);
      return;
    }
    
    // Проверяем доступность модуля
    if (!bleProvider.isModuleAvailable(moduleIndex)) {
      final status = bleProvider.getModuleStatus(moduleIndex);
      _showErrorDialog(
        l10n.moduleBusy, 
        l10n.moduleBusyMessage(moduleIndex + 1, status)
      );
      return;
    }
    
    final config = _recordConfigs[moduleIndex];
    
    try {
      // Отправляем команду джамминга с параметрами из текущей конфигурации
      await bleProvider.sendStartJamCommand(
        module: moduleIndex,
        frequency: config.frequency,
        power: 7, // Максимальная мощность по умолчанию
        patternType: 0, // Random pattern по умолчанию
        maxDurationMs: 60000, // 60 секунд
        cooldownMs: 5000, // 5 секунд пауза
      );
      
      // Запрашиваем актуальное состояние устройства
      await bleProvider.sendGetStateCommand();
      
      _showSuccessSnackBar(l10n.jammingStarted(moduleIndex + 1));
    } catch (e) {
      _showErrorDialog(l10n.jammingError, l10n.jammingStartFailed(e.toString()));
    }
  }

  void _stopJamming(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    
    if (!bleProvider.isConnected) {
      _showErrorDialog(l10n.error, l10n.deviceNotConnected);
      return;
    }
    
    try {
      await bleProvider.sendIdleCommand(moduleIndex);
      await bleProvider.sendGetStateCommand();
      _showSuccessSnackBar(l10n.jammingStopped(moduleIndex + 1));
    } catch (e) {
      _showErrorDialog(l10n.jammingError, l10n.jammingStopFailed(e.toString()));
    }
  }

  void _startRecording(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    final l10n = AppLocalizations.of(context)!;
    if (!bleProvider.isConnected) {
      _showErrorDialog(l10n.error, l10n.deviceNotConnected);
      return;
    }
    
    // Проверяем доступность модуля
    if (!bleProvider.isModuleAvailable(moduleIndex)) {
      final status = bleProvider.getModuleStatus(moduleIndex);
      _showErrorDialog(
        l10n.moduleBusy, 
        l10n.moduleBusyMessage(moduleIndex + 1, status)
      );
      return;
    }
    
    final config = _recordConfigs[moduleIndex];
    final errors = bleProvider.validateRecordConfig(config);
    
    if (errors.isNotEmpty) {
      _showErrorDialog(l10n.validationError, errors.join('\n'));
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
       
       _showSuccessSnackBar(l10n.recordingStarted(moduleIndex + 1));
     } catch (e) {
       _showErrorDialog(l10n.recordingError, l10n.recordingStartFailed(e.toString()));
     }
  }
  
  void _stopRecording(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    try {
      await bleProvider.sendIdleCommand(moduleIndex);
      
      // Запрашиваем актуальное состояние устройства
      await bleProvider.sendGetStateCommand();
      
      final l10n = AppLocalizations.of(context)!;
      _showSuccessSnackBar(l10n.recordingStopped(moduleIndex + 1));
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      _showErrorDialog(l10n.error, l10n.recordingStopFailed(e.toString()));
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

  /// Оверлей затемнения когда модуль занят
  Widget _buildBusyOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.primaryBackground.withOpacity(0.9),
        child: Center(
          child: Consumer<BleProvider>(
            builder: (context, bleProvider, child) {
              final status = bleProvider.getModuleStatus(_selectedModule);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.moduleBusy,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
            color: AppColors.logBackground.withOpacity(0.95),
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
                        color: AppColors.recording.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.recording,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.fiber_manual_record,
                        color: AppColors.recording,
                        size: 24,
                      ),
                    ),
                        const SizedBox(width: 12),
                        // Текст "Recording"
                    Text(
                      AppLocalizations.of(context)!.recordingShort,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.recording,
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primaryText),
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
              Icons.graphic_eq,
              '${config.frequency.toStringAsFixed(1)} ${AppLocalizations.of(context)!.mhz}',
              AppLocalizations.of(context)!.freqShort,
            ),
            const SizedBox(width: 11),
            _buildInfoItem(
              context,
              Icons.radio,
              config.modulationName,
              AppLocalizations.of(context)!.modShort,
            ),
          ],
        ),
        const SizedBox(height: 9),
        // Вторая строка: Rate, BW, Dev (с Wrap для переноса)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 11,
          runSpacing: 9,
          children: [
            _buildInfoItem(
              context,
              Icons.speed,
              '${(config.dataRate / 1000).toStringAsFixed(1)} ${AppLocalizations.of(context)!.kbaud}',
              AppLocalizations.of(context)!.rateShort,
            ),
            _buildInfoItem(
              context,
              Icons.straighten,
              '${(config.bandwidth / 1000).toStringAsFixed(1)} ${AppLocalizations.of(context)!.khz}',
              AppLocalizations.of(context)!.bwShort,
        ),
            // Deviation для FM модуляций (2-FSK, GFSK, 4-FSK) - показываем всегда для FSK модуляций
            if (config.modulationName.contains('FSK') || config.modulation == 0 || config.modulation == 1)
          _buildInfoItem(
            context,
            Icons.tune,
            '${(config.deviation / 1000).toStringAsFixed(2)} ${AppLocalizations.of(context)!.khz}',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.primaryText.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText,
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
                  _hasAutoSwitched = false; // Сбрасываем флаг при ручном переключении
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
                      final isRecording = bleProvider.isModuleRecording(index);
                      final isJamming = bleProvider.isModuleJamming(index);
                      final isBusy = !isAvailable || isRecording || isJamming;
                      final status = bleProvider.getModuleStatus(index);
                      
                return Tab(
                        icon: Stack(
                          children: [
                            Icon(
                              Icons.settings_input_antenna, 
                              size: 18,
                              color: isAvailable ? null : AppColors.disabledText,
                            ),
                            if (isBusy)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                  text: AppLocalizations.of(context)!.subGhzModule(index + 1),
                  iconMargin: const EdgeInsets.only(bottom: 2),
                      );
                    },
                );
              }).toList(),
              ) : const Center(child: CircularProgressIndicator()),
            ),
                 
                 // Выбор действия
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   color: Theme.of(context).colorScheme.surface,
                   width: double.infinity,
                   child: SegmentedButton<ModuleAction>(
                     style: SegmentedButton.styleFrom(
                       shape: const RoundedRectangleBorder(
                         borderRadius: BorderRadius.zero,
                       ),
                     ),
                     showSelectedIcon: false,
                     segments: [
                       ButtonSegment<ModuleAction>(
                         value: ModuleAction.recording,
                         label: Text(AppLocalizations.of(context)!.recording),
                       ),
                       ButtonSegment<ModuleAction>(
                         value: ModuleAction.jamming,
                         label: Text(AppLocalizations.of(context)!.jamming),
                       ),
                     ],
                     selected: {_selectedActions[_selectedModule]},
                     onSelectionChanged: (Set<ModuleAction> newSelection) {
                       setState(() {
                         _selectedActions[_selectedModule] = newSelection.first;
                       });
                     },
                   ),
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
            
            // Кнопка записи/остановки поиска частоты прилеплена к низу
            _buildBottomButton(),
        ],
        ),
      ),
    );
  }
  
  Widget _buildModuleTab(int moduleIndex, RecordConfig config) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isRecording = bleProvider.isModuleRecording(moduleIndex);
        final isJamming = bleProvider.isModuleJamming(moduleIndex);
        final isBusy = _isModuleBusy(moduleIndex, bleProvider);
        
        final selectedAction = _selectedActions[moduleIndex];
        print('RecordScreen: Module $moduleIndex, isRecording=$isRecording, isJamming=$isJamming, isBusy=$isBusy');
        print('RecordScreen: Current selected module: $_selectedModule, action: $selectedAction');
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Настройки записи/джамминга с оверлеем
              Stack(
                children: [
                  _buildRecordSettings(moduleIndex, config, isBusy, selectedAction),
                  // Оверлей затемнения когда модуль занят
                  if (isBusy) _buildBusyOverlay(),
                  // Оверлей записи только на область настроек
                  if (isRecording) _buildRecordSettingsOverlay(),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Список файлов только для Recording
              if (selectedAction == ModuleAction.recording)
                _buildModuleFilesList(moduleIndex),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomButton() {
    // Определяем состояние кнопки вне Consumer для правильной работы анимации
    final bleProvider = Provider.of<BleProvider>(context, listen: true);
    final isRecording = bleProvider.isModuleRecording(_selectedModule);
    final isJamming = bleProvider.isModuleJamming(_selectedModule);
    final isAvailable = bleProvider.isModuleAvailable(_selectedModule);
    final isFrequencySearching = bleProvider.isModuleFrequencySearching(_selectedModule);
    
    final selectedAction = _selectedActions[_selectedModule];
    final l10n = AppLocalizations.of(context)!;
    
    // Если идет поиск частоты, показываем кнопку остановки поиска
    if (isFrequencySearching) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          border: Border(
            top: BorderSide(
              color: AppColors.divider,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _stopFrequencySearch(_selectedModule, bleProvider),
              icon: const Icon(Icons.stop, color: AppColors.primaryBackground),
              label: Text('${l10n.stopFrequencySearch} (${l10n.module(_selectedModule + 1)})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.primaryBackground,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Обычная кнопка записи/джамминга
    String buttonText;
    IconData buttonIcon;
    Color buttonColor;
    VoidCallback? onPressed;
    
    if (selectedAction == ModuleAction.recording) {
      if (isRecording) {
        buttonText = l10n.stopRecording;
        buttonIcon = Icons.stop;
        buttonColor = AppColors.error; // Остановка записи - красный
        onPressed = () => _stopRecording(_selectedModule);
      } else {
        buttonText = l10n.startRecording;
        buttonIcon = Icons.radio_button_checked; // Та же иконка что и в меню
        buttonColor = AppColors.primaryAccent; // Синий для старта
        onPressed = isAvailable ? () => _startRecording(_selectedModule) : null;
      }
    } else { // jamming
      if (isJamming) {
        buttonText = l10n.stopJamming;
        buttonIcon = Icons.stop;
        buttonColor = AppColors.error; // Остановка глушения - красный
        onPressed = () => _stopJamming(_selectedModule);
      } else {
        buttonText = l10n.startJamming;
        buttonIcon = Icons.block;
        buttonColor = AppColors.primaryAccent; // Синий для старта
        onPressed = isAvailable ? () => _startJamming(_selectedModule) : null;
      }
    }
    
    if (!isAvailable && !isRecording && !isJamming) {
      buttonText = l10n.moduleBusy;
      buttonIcon = Icons.block;
      buttonColor = AppColors.disabledText;
      onPressed = null;
    }
    
    return Container(
      key: ValueKey('action_button_$_selectedModule${_selectedActions[_selectedModule]}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
            child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon, color: AppColors.primaryBackground),
            label: Text('$buttonText (${l10n.module(_selectedModule + 1)})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: AppColors.primaryBackground,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
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
              (config.advancedMode && _isAdvancedExpanded[moduleIndex]) ? AppLocalizations.of(context)!.presets : AppLocalizations.of(context)!.advanced,
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
        statusColor = AppColors.idle;
        statusIcon = Icons.pause_circle;
        break;
      case 'recordsignal':
        statusColor = AppColors.recording;
        statusIcon = Icons.fiber_manual_record;
        break;
      case 'detectsignal':
        statusColor = AppColors.searching;
        statusIcon = Icons.radar;
        break;
      default:
        statusColor = AppColors.secondaryText;
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
                      '${config.frequency}${AppLocalizations.of(context)!.mhz}, ${config.dataRate}${AppLocalizations.of(context)!.kbaud}',
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
  
  Widget _buildRecordSettings(int moduleIndex, RecordConfig config, bool isBusy, ModuleAction selectedAction) {
    final l10n = AppLocalizations.of(context)!;
    final title = selectedAction == ModuleAction.recording 
        ? l10n.recordSettings 
        : l10n.jammingSettings;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
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
                       
                       // Check if frequency search is active - if so, don't update the dropdown
                       final isFrequencySearching = bleProvider.isModuleFrequencySearching(moduleIndex);
                       
                       if (moduleSignals.isNotEmpty && !isFrequencySearching) {
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
                         onChanged: (!isBusy && !bleProvider.isModuleFrequencySearching(moduleIndex)) ? (value) {
                 if (value != null) {
                             final frequency = double.tryParse(value);
                             if (frequency != null) {
                               _updateConfig(moduleIndex, config.copyWith(frequency: frequency));
                             }
                 }
               } : null,
                         decoration: InputDecoration(
                           labelText: '${AppLocalizations.of(context)!.frequency} (${AppLocalizations.of(context)!.mhz})',
                           border: const OutlineInputBorder(),
                           prefixIcon: const Icon(Icons.graphic_eq),
                           suffixIcon: shouldShowIcon ? 
                             Icon(
                               Icons.check_circle,
                               color: AppColors.success,
                               size: 16,
                             ) : null,
                           isDense: true,
                           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         ),
                         isDense: true,
                         items: CC1101Values.frequencies.map((freq) {
                           return DropdownMenuItem<String>(
                             value: freq,
                             child: Text(
                               freq,
                               style: TextStyle(color: AppColors.secondaryText),
                             ),
                           );
                         }).toList(),
                         dropdownColor: AppColors.secondaryBackground,
                         style: TextStyle(color: AppColors.primaryText),
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
                         color: isSearching ? AppColors.error : null,
                       ),
                       tooltip: isSearching ? AppLocalizations.of(context)!.stopFrequencySearch : AppLocalizations.of(context)!.searchForFrequency,
                       style: IconButton.styleFrom(
                         backgroundColor: isSearching ? AppColors.error.withOpacity(0.1) : null,
               ),
                     );
                   },
                 ),
               ],
             ),
            
            const SizedBox(height: 12),
            
            // Настройки в зависимости от действия
            if (selectedAction == ModuleAction.recording) ...[
              // Настройки записи в зависимости от режима
              if (config.advancedMode && _isAdvancedExpanded[moduleIndex]) ...[
                _buildAdvancedSettings(moduleIndex, config, isBusy),
              ] else ...[
                _buildSimpleSettings(moduleIndex, config, isBusy),
              ],
              // Узкая полоска с кнопкой "advanced" внизу формы
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildAdvancedModeToggle(moduleIndex, config),
              ),
            ] else ...[
              // Настройки для jamming (только частота, так как остальные параметры фиксированы)
              // Для jamming показываем только частоту, остальные параметры передаются с фиксированными значениями
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSimpleSettings(int moduleIndex, RecordConfig config, bool isBusy) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isFrequencySearching = bleProvider.isModuleFrequencySearching(moduleIndex);
    return PresetSelector(
      value: config.preset,
          onChanged: (isBusy || isFrequencySearching) ? null : (value) {
        if (value != null) {
          _updateConfig(moduleIndex, config.copyWith(preset: value));
        }
          },
        );
      },
    );
  }
  
  Widget _buildAdvancedSettings(int moduleIndex, RecordConfig config, bool isBusy) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isFrequencySearching = bleProvider.isModuleFrequencySearching(moduleIndex);
    return Column(
      children: [
        // Полоса пропускания
        BandwidthSelector(
          controller: _bandwidthControllers[moduleIndex],
          value: config.rxBandwidth,
              onChanged: (isBusy || isFrequencySearching) ? null : (value) {
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
              onChanged: (isBusy || isFrequencySearching) ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(dataRate: value));
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Тип модуляции
        ModulationSelector(
          value: config.modulation,
              onChanged: (isBusy || isFrequencySearching) ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(modulation: value));
            }
          },
        ),
        
        // Девиация (для всех FM модуляций: 2-FSK, GFSK, 4-FSK, MSK)
        if (config.modulation != null && 
            (config.modulation == '2-FSK' || 
             config.modulation == 'GFSK' || 
             config.modulation == '4-FSK' || 
             config.modulation == 'MSK')) ...[
          const SizedBox(height: 16),
          DeviationInputField(
            controller: _deviationControllers[moduleIndex],
            value: config.deviation,
                onChanged: (isBusy || isFrequencySearching) ? null : (value) {
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
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок как у формы настроек
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                AppLocalizations.of(context)!.signalsCaptured(moduleIndex + 1, moduleFiles.length),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            // Список файлов без заголовка
            SizedBox(
              height: 200,
              child: FileListWidget(
                files: moduleFiles,
                mode: FileListMode.local,
                title: AppLocalizations.of(context)!.signalsCaptured(moduleIndex + 1, moduleFiles.length),
                showHeader: false,
                showActions: true,
                filterExtension: 'sub',
                onRefresh: null, // Отключаем pull-to-refresh
                onFileSelected: (file) => _openFileViewer(file),
                onFileAction: (file, action) => _handleRecordedFileAction(file, action),
              ),
            ),
          ],
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
            title: AppLocalizations.of(context)!.recordedFiles,
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
          filePath: file.name,
          pathType: 1,  // SIGNALS
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
        // Получаем дату из объекта файла
        DateTime? fileDate;
        try {
          if (file.dateCreated != null) {
            fileDate = file.dateCreated as DateTime?;
          }
        } catch (e) {
          // Если не удалось получить дату из объекта, попробуем найти в recordedRuntimeFiles
        }
        // Если дата не найдена в объекте, ищем в recordedRuntimeFiles
        if (fileDate == null) {
          final runtimeFiles = bleProvider.recordedRuntimeFiles ?? [];
          for (final runtimeFile in runtimeFiles) {
            String fileName;
            if (runtimeFile is Map<String, dynamic> && runtimeFile.containsKey('filename')) {
              fileName = runtimeFile['filename'].toString();
              if (fileName == file.name && runtimeFile.containsKey('date')) {
                try {
                  if (runtimeFile['date'] is String) {
                    fileDate = DateTime.tryParse(runtimeFile['date']);
                  } else if (runtimeFile['date'] is int) {
                    // Unix timestamp
                    fileDate = DateTime.fromMillisecondsSinceEpoch(runtimeFile['date'] * 1000);
                  }
                } catch (e) {
                  print('Error parsing date for file ${file.name}: $e');
                }
                break;
              }
            }
          }
        }
        _saveToSignalsDirectory(file.name, bleProvider, fileDate: fileDate);
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
    final confirmed = await TransmitFileDialog.showAndTransmit(
      context,
      fileName: filename,
      filePath: filename,
      pathType: 1, // SIGNALS
    );
    if (!confirmed) {
      return;
    }
  }

  void _saveToSignalsDirectory(String filename, BleProvider bleProvider, {DateTime? fileDate}) async {
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
          title: Text(AppLocalizations.of(context)!.saveSignal),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.enterSignalName),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.signalName,
                  hintText: AppLocalizations.of(context)!.enterSignalName,
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
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop(name);
                }
              },
              child: Text(AppLocalizations.of(context)!.create),
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
        // Передаем дату файла для сохранения
        await bleProvider.saveFileToSignalsWithName(
          sourcePath, 
          targetName, 
          pathType: 0,
          preserveDate: fileDate,
        );
        _showSuccessSnackBar(AppLocalizations.of(context)!.signalSavedAs(targetName));
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
          title: Text(AppLocalizations.of(context)!.deleteSignal),
          content: Text(AppLocalizations.of(context)!.deleteSignalConfirm(filename)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.primaryText,
              ),
              child: Text(AppLocalizations.of(context)!.delete),
                  ),
                ],
        );
      },
    );
    
    if (result == true) {
      try {
        // Удаляем файл из SIGNALS
        await bleProvider.deleteFile(filename, pathType: 1);  // SIGNALS
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
        title: Text(AppLocalizations.of(context)!.recordScreenHelp),
        content: SingleChildScrollView(
          child: Text(
            'This screen allows you to record RF signals using the CC1101 modules.\n\n'
            '• Select a module tab to configure its settings\n'
            '• Choose between Simple and Advanced modes\n'
            '• Simple mode uses presets for quick setup\n'
            '• Advanced mode allows fine-tuning of parameters\n'
            '• ${AppLocalizations.of(context)!.startRecordingToCaptureSignals}\n'
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
