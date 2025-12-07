# Record Screen - Перенос из VueJS

## Описание
Экран для записи сигналов с настройками модулей CC1101. Позволяет настраивать параметры записи и управлять процессом записи.

## VueJS версия (PageRecord.vue)

### Основные функции:
1. **Детектор частот** - выбор частоты из обнаруженных сигналов
2. **Настройки модулей** - конфигурация параметров CC1101
3. **Режимы записи** - простой и расширенный режим
4. **Управление записью** - кнопки старт/стоп
5. **Список записанных файлов** - отображение runtime файлов

### Ключевые компоненты:
- `Detector` - детектор частот
- `RecordButton` - кнопка записи
- `FilesList` - список файлов
- Настройки модулей с вкладками

## Текущая Android версия
- Базовая функциональность сканирования в `SignalScannerScreen`
- Простое отображение обнаруженных сигналов

## Что нужно перенести

### 1. Детектор частот
```dart
class FrequencyDetectorWidget extends StatefulWidget {
  @override
  _FrequencyDetectorWidgetState createState() => _FrequencyDetectorWidgetState();
}

class _FrequencyDetectorWidgetState extends State<FrequencyDetectorWidget> {
  List<DetectedSignal> detectedFrequencies = [];
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Frequency Detector'),
            trailing: IconButton(
              icon: Icon(Icons.radar),
              onPressed: _startScan,
            ),
          ),
          if (detectedFrequencies.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              itemCount: detectedFrequencies.length,
              itemBuilder: (context, index) {
                final signal = detectedFrequencies[index];
                return ListTile(
                  title: Text('${signal.frequency} MHz'),
                  subtitle: Text('RSSI: ${signal.rssi} dBm'),
                  trailing: TextButton(
                    onPressed: () => _selectFrequency(signal.frequency),
                    child: Text('Select'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  void _startScan() {
    // Запуск сканирования частот
    context.read<BleProvider>().sendCommand('scan -100 0');
  }
  
  void _selectFrequency(String frequency) {
    // Выбор частоты для записи
  }
}
```

### 2. Настройки модулей CC1101
```dart
class ModuleSettingsWidget extends StatefulWidget {
  final int moduleIndex;
  
  @override
  _ModuleSettingsWidgetState createState() => _ModuleSettingsWidgetState();
}

class _ModuleSettingsWidgetState extends State<ModuleSettingsWidget> {
  String frequency = '433.92';
  String preset = 'Ook270';
  String modulation = '2'; // 0=2-FSK, 2=ASK/OOK
  String bandwidth = '650.000';
  String dataRate = '512';
  String deviation = '1.5869';
  bool advancedMode = false;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Module ${widget.moduleIndex + 1} Settings'),
            trailing: Switch(
              value: advancedMode,
              onChanged: (value) => setState(() => advancedMode = value),
            ),
          ),
          if (advancedMode) ...[
            _buildAdvancedSettings(),
          ] else ...[
            _buildSimpleSettings(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSimpleSettings() {
    return Column(
      children: [
        _buildFrequencyField(),
        _buildPresetField(),
      ],
    );
  }
  
  Widget _buildAdvancedSettings() {
    return Column(
      children: [
        _buildFrequencyField(),
        _buildBandwidthField(),
        _buildDataRateField(),
        if (modulation == '0') _buildDeviationField(),
        _buildModulationSelector(),
      ],
    );
  }
  
  Widget _buildFrequencyField() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: TextFormField(
        initialValue: frequency,
        decoration: InputDecoration(
          labelText: 'Frequency (MHz)',
          helperText: '300-348, 387-464, 779-928 MHz',
        ),
        onChanged: (value) => setState(() => frequency = value),
      ),
    );
  }
  
  // Другие поля настроек...
}
```

### 3. Кнопка записи
```dart
class RecordButtonWidget extends StatefulWidget {
  final int moduleIndex;
  final Function(int module) onStartRecord;
  final Function(int module) onStopRecord;
  
  @override
  _RecordButtonWidgetState createState() => _RecordButtonWidgetState();
}

class _RecordButtonWidgetState extends State<RecordButtonWidget> {
  bool isRecording = false;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        // Проверяем состояние модуля
        final moduleState = bleProvider.cc1101Modules?[widget.moduleIndex];
        final isModuleBusy = moduleState?['mode'] != 'Idle';
        
        return ElevatedButton.icon(
          onPressed: isModuleBusy ? null : _toggleRecording,
          icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
          label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isRecording ? Colors.red : Colors.green,
          ),
        );
      },
    );
  }
  
  void _toggleRecording() {
    setState(() => isRecording = !isRecording);
    
    if (isRecording) {
      widget.onStartRecord(widget.moduleIndex);
    } else {
      widget.onStopRecord(widget.moduleIndex);
    }
  }
}
```

### 4. Список записанных файлов
```dart
class RecordedFilesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final runtimeFiles = bleProvider.recordedRuntimeFiles;
        
        if (runtimeFiles.isEmpty) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No recorded files'),
            ),
          );
        }
        
        return Card(
          child: Column(
            children: [
              ListTile(
                title: Text('Recorded Files'),
                trailing: IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () => bleProvider.sendCommand('getState'),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: runtimeFiles.length,
                itemBuilder: (context, index) {
                  final file = runtimeFiles[index];
                  return ListTile(
                    leading: Icon(Icons.radio),
                    title: Text(file.filename),
                    subtitle: Text(file.date ?? 'Unknown date'),
                    trailing: IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () => _transmitFile(file.filename),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _transmitFile(String filename) {
    context.read<BleProvider>().sendCommand('tx.file $filename');
  }
}
```

## Новый экран RecordScreen

```dart
class RecordScreen extends StatefulWidget {
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<ModuleSettingsWidget> _moduleSettings = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 модуля
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record Signals'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Module 1'),
            Tab(text: 'Module 2'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.radar),
            onPressed: _startFrequencyScan,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModuleTab(0),
          _buildModuleTab(1),
        ],
      ),
    );
  }
  
  Widget _buildModuleTab(int moduleIndex) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          FrequencyDetectorWidget(
            onFrequencySelected: (frequency) => _selectFrequency(moduleIndex, frequency),
          ),
          SizedBox(height: 16),
          ModuleSettingsWidget(moduleIndex: moduleIndex),
          SizedBox(height: 16),
          RecordButtonWidget(
            moduleIndex: moduleIndex,
            onStartRecord: _startRecord,
            onStopRecord: _stopRecord,
          ),
          SizedBox(height: 16),
          RecordedFilesWidget(),
        ],
      ),
    );
  }
  
  void _startFrequencyScan() {
    context.read<BleProvider>().sendCommand('scan -100 0');
  }
  
  void _selectFrequency(int moduleIndex, String frequency) {
    // Обновить частоту для выбранного модуля
  }
  
  void _startRecord(int moduleIndex) {
    // Запуск записи для модуля
    final settings = _moduleSettings[moduleIndex];
    final command = _buildRecordCommand(moduleIndex, settings);
    context.read<BleProvider>().sendCommand(command);
  }
  
  void _stopRecord(int moduleIndex) {
    // Остановка записи
    context.read<BleProvider>().sendCommand('idle $moduleIndex');
  }
  
  String _buildRecordCommand(int moduleIndex, ModuleSettingsWidget settings) {
    // Построение команды записи на основе настроек
    return 'record ${settings.frequency} ${settings.preset} $moduleIndex';
  }
}
```

## Задачи для реализации
- [ ] Создать FrequencyDetectorWidget
- [ ] Создать ModuleSettingsWidget с настройками CC1101
- [ ] Создать RecordButtonWidget
- [ ] Создать RecordedFilesWidget
- [ ] Создать новый RecordScreen
- [ ] Интегрировать с существующим BleProvider
- [ ] Добавить валидацию параметров CC1101
- [ ] Протестировать функциональность записи
- [ ] Добавить обработку ошибок

