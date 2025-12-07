# Transmit Screen - Перенос из VueJS

## Описание
Экран для передачи сигналов через модули CC1101. Позволяет настраивать параметры передачи и отправлять сигналы.

## VueJS версия (PageTransmit.vue)

### Основные функции:
1. **Настройки модулей** - конфигурация параметров передачи
2. **Режимы передачи** - простой и расширенный режим
3. **Raw передача** - отправка сырых данных
4. **Управление передачей** - кнопки отправки

### Ключевые компоненты:
- Настройки модулей с вкладками
- Raw данные для передачи
- Кнопки отправки

## Текущая Android версия
- Отсутствует отдельный экран для передачи
- Базовая функциональность в других экранах

## Что нужно перенести

### 1. Настройки передачи модулей
```dart
class TransmitModuleSettingsWidget extends StatefulWidget {
  final int moduleIndex;
  
  @override
  _TransmitModuleSettingsWidgetState createState() => _TransmitModuleSettingsWidgetState();
}

class _TransmitModuleSettingsWidgetState extends State<TransmitModuleSettingsWidget> {
  String frequency = '433.92';
  String preset = 'Ook270';
  String modulation = '2'; // 0=2-FSK, 2=ASK/OOK
  String deviation = '1.5869';
  bool advancedMode = false;
  final TextEditingController _rawDataController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Module ${widget.moduleIndex + 1} Transmit Settings'),
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
          SizedBox(height: 16),
          _buildRawDataSection(),
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
        if (modulation == '0') _buildDeviationField(),
        _buildModulationSelector(),
      ],
    );
  }
  
  Widget _buildRawDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Raw Data', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8),
        TextField(
          controller: _rawDataController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Enter raw data to transmit...',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: _sendRawData,
              child: Text('Send Raw'),
            ),
          ],
        ),
      ],
    );
  }
  
  void _sendRawData() {
    if (_rawDataController.text.isNotEmpty) {
      final command = _buildTransmitCommand();
      context.read<BleProvider>().sendCommand(command);
    }
  }
  
  String _buildTransmitCommand() {
    if (advancedMode) {
      return 'tx.bin $frequency 100 ${_rawDataController.text}';
    } else {
      return 'tx.raw $frequency ${_rawDataController.text}';
    }
  }
}
```

### 2. Виджет для передачи файлов
```dart
class TransmitFileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final files = bleProvider.fileList.where((file) => 
          file.type == 'file' && 
          (file.name.endsWith('.sub') || file.name.endsWith('.json'))
        ).toList();
        
        if (files.isEmpty) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No signal files found'),
            ),
          );
        }
        
        return Card(
          child: Column(
            children: [
              ListTile(
                title: Text('Transmit from File'),
                subtitle: Text('Select a file to transmit'),
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return ListTile(
                    leading: Icon(Icons.radio),
                    title: Text(file.name),
                    subtitle: Text(file.size ?? 'Unknown size'),
                    trailing: IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () => _transmitFile(file.name),
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

### 3. Быстрая передача предустановок
```dart
class QuickTransmitWidget extends StatefulWidget {
  @override
  _QuickTransmitWidgetState createState() => _QuickTransmitWidgetState();
}

class _QuickTransmitWidgetState extends State<QuickTransmitWidget> {
  final List<Map<String, dynamic>> _presets = [
    {
      'name': 'Garage Door',
      'frequency': '433.92',
      'data': '1010101010101010',
      'preset': 'Ook270',
    },
    {
      'name': 'Car Alarm',
      'frequency': '315.00',
      'data': '1100110011001100',
      'preset': 'Ook270',
    },
    {
      'name': 'Gate Remote',
      'frequency': '433.92',
      'data': '1111000011110000',
      'preset': 'Ook270',
    },
  ];
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Quick Transmit'),
            subtitle: Text('Common signal presets'),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: _presets.length,
            itemBuilder: (context, index) {
              final preset = _presets[index];
              return ListTile(
                leading: Icon(Icons.flash_on),
                title: Text(preset['name']),
                subtitle: Text('${preset['frequency']} MHz - ${preset['preset']}'),
                trailing: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _transmitPreset(preset),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _transmitPreset(Map<String, dynamic> preset) {
    final command = 'tx.bin ${preset['frequency']} 100 ${preset['data']}';
    context.read<BleProvider>().sendCommand(command);
  }
}
```

## Новый экран TransmitScreen

```dart
class TransmitScreen extends StatefulWidget {
  @override
  _TransmitScreenState createState() => _TransmitScreenState();
}

class _TransmitScreenState extends State<TransmitScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 модуля
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transmit Signals'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Module 1'),
            Tab(text: 'Module 2'),
          ],
        ),
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
          TransmitModuleSettingsWidget(moduleIndex: moduleIndex),
          SizedBox(height: 16),
          TransmitFileWidget(),
          SizedBox(height: 16),
          QuickTransmitWidget(),
        ],
      ),
    );
  }
}
```

### 4. Индикатор состояния передачи
```dart
class TransmitStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final modules = bleProvider.cc1101Modules ?? [];
        final transmittingModules = modules.where((module) => 
          module['mode'] == 'SendSignal'
        ).toList();
        
        if (transmittingModules.isEmpty) {
          return SizedBox.shrink();
        }
        
        return Card(
          color: Colors.orange.shade100,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.send, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Transmitting on ${transmittingModules.length} module(s)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: () => _stopAllTransmissions(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _stopAllTransmissions() {
    final bleProvider = context.read<BleProvider>();
    for (int i = 0; i < 2; i++) {
      bleProvider.sendCommand('idle $i');
    }
  }
}
```

### 5. История передач
```dart
class TransmitHistoryWidget extends StatefulWidget {
  @override
  _TransmitHistoryWidgetState createState() => _TransmitHistoryWidgetState();
}

class _TransmitHistoryWidgetState extends State<TransmitHistoryWidget> {
  List<Map<String, dynamic>> _transmitHistory = [];
  
  @override
  Widget build(BuildContext context) {
    if (_transmitHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No transmission history'),
        ),
      );
    }
    
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Transmission History'),
            trailing: IconButton(
              icon: Icon(Icons.clear),
              onPressed: _clearHistory,
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: _transmitHistory.length,
            itemBuilder: (context, index) {
              final entry = _transmitHistory[index];
              return ListTile(
                leading: Icon(Icons.history),
                title: Text(entry['type']),
                subtitle: Text('${entry['frequency']} MHz - ${entry['timestamp']}'),
                trailing: IconButton(
                  icon: Icon(Icons.replay),
                  onPressed: () => _retransmit(entry),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _clearHistory() {
    setState(() {
      _transmitHistory.clear();
    });
  }
  
  void _retransmit(Map<String, dynamic> entry) {
    final command = entry['command'];
    context.read<BleProvider>().sendCommand(command);
  }
  
  void addTransmission(Map<String, dynamic> entry) {
    setState(() {
      _transmitHistory.insert(0, entry);
      if (_transmitHistory.length > 50) {
        _transmitHistory = _transmitHistory.take(50).toList();
      }
    });
  }
}
```

## Задачи для реализации
- [ ] Создать TransmitModuleSettingsWidget
- [ ] Создать TransmitFileWidget
- [ ] Создать QuickTransmitWidget
- [ ] Создать TransmitStatusWidget
- [ ] Создать TransmitHistoryWidget
- [ ] Создать новый TransmitScreen
- [ ] Интегрировать с существующим BleProvider
- [ ] Добавить валидацию данных для передачи
- [ ] Протестировать функциональность передачи
- [ ] Добавить обработку ошибок
- [ ] Добавить подтверждения перед передачей
- [ ] Реализовать сохранение истории передач

