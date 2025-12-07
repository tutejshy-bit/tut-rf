# Editor Screen - Перенос из VueJS

## Описание
Экран редактора сигналов для создания и редактирования сигналов. Позволяет создавать новые сигналы, редактировать существующие и сохранять их.

## VueJS версия (PageEditor.vue)

### Основные функции:
1. **Редактор сигналов** - создание и редактирование сигналов
2. **Предварительный просмотр** - визуализация сигнала
3. **Сохранение** - сохранение сигналов в файлы
4. **Импорт/Экспорт** - работа с различными форматами

## Текущая Android версия
- Отсутствует отдельный экран редактора
- Базовая функциональность просмотра файлов

## Что нужно создать

### 1. Основной редактор сигналов
```dart
class SignalEditorWidget extends StatefulWidget {
  final String? initialContent;
  final String? fileName;
  
  @override
  _SignalEditorWidgetState createState() => _SignalEditorWidgetState();
}

class _SignalEditorWidgetState extends State<SignalEditorWidget> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  bool isDirty = false;
  bool isPreviewMode = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
    if (widget.fileName != null) {
      _fileNameController.text = widget.fileName!;
    }
    
    _contentController.addListener(_onContentChanged);
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: isPreviewMode ? _buildPreview() : _buildEditor(),
        ),
        _buildBottomBar(),
      ],
    );
  }
  
  Widget _buildToolbar() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: isDirty ? _saveFile : null,
            ),
            IconButton(
              icon: Icon(Icons.folder_open),
              onPressed: _openFile,
            ),
            IconButton(
              icon: Icon(Icons.preview),
              onPressed: _togglePreview,
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: _transmitSignal,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEditor() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _fileNameController,
            decoration: InputDecoration(
              labelText: 'File Name',
              hintText: 'Enter file name...',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                labelText: 'Signal Data',
                hintText: 'Enter signal data...',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreview() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signal Preview', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: _buildSignalVisualization(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSignalVisualization() {
    // Простая визуализация сигнала
    String content = _contentController.text;
    if (content.isEmpty) {
      return Text('No signal data to preview');
    }
    
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Raw Data:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          SelectableText(
            content,
            style: TextStyle(fontFamily: 'monospace'),
          ),
          SizedBox(height: 16),
          Text('Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          ..._analyzeSignal(content),
        ],
      ),
    );
  }
  
  List<Widget> _analyzeSignal(String content) {
    List<Widget> widgets = [];
    
    // Простой анализ сигнала
    if (content.contains('1') && content.contains('0')) {
      widgets.add(Text('• Binary signal detected'));
    }
    
    if (content.contains(' ')) {
      widgets.add(Text('• Contains spaces (timing data?)'));
    }
    
    widgets.add(Text('• Length: ${content.length} characters'));
    
    return widgets;
  }
  
  Widget _buildBottomBar() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            if (isDirty) ...[
              Icon(Icons.circle, size: 8, color: Colors.orange),
              SizedBox(width: 8),
              Text('Unsaved changes'),
            ],
            Spacer(),
            Text('Lines: ${_contentController.text.split('\n').length}'),
          ],
        ),
      ),
    );
  }
  
  void _onContentChanged() {
    setState(() {
      isDirty = true;
    });
  }
  
  void _saveFile() async {
    if (_fileNameController.text.isEmpty) {
      _showSaveAsDialog();
      return;
    }
    
    try {
      // Сохранение файла на ESP32
      String command = 'sd.write ${_fileNameController.text} "${_contentController.text}"';
      await context.read<BleProvider>().sendCommand(command);
      
      setState(() {
        isDirty = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }
  
  void _showSaveAsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save As'),
        content: TextField(
          controller: _fileNameController,
          decoration: InputDecoration(
            labelText: 'File Name',
            hintText: 'Enter file name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveFile();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _openFile() {
    // Открытие файла для редактирования
    showDialog(
      context: context,
      builder: (context) => FilePickerDialog(
        onFileSelected: (file) => _loadFile(file),
      ),
    );
  }
  
  void _loadFile(String filePath) async {
    try {
      final content = await context.read<BleProvider>().readFileContent(filePath);
      _contentController.text = content;
      _fileNameController.text = filePath.split('/').last;
      setState(() {
        isDirty = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading file: $e')),
      );
    }
  }
  
  void _togglePreview() {
    setState(() {
      isPreviewMode = !isPreviewMode;
    });
  }
  
  void _transmitSignal() {
    if (_contentController.text.isNotEmpty) {
      String command = 'tx.raw 433.92 "${_contentController.text}"';
      context.read<BleProvider>().sendCommand(command);
    }
  }
}
```

### 2. Диалог выбора файла
```dart
class FilePickerDialog extends StatelessWidget {
  final Function(String) onFileSelected;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final files = bleProvider.fileList.where((file) => 
          file.type == 'file' && 
          (file.name.endsWith('.sub') || file.name.endsWith('.json') || file.name.endsWith('.txt'))
        ).toList();
        
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                AppBar(
                  title: Text('Select File'),
                  automaticallyImplyLeading: false,
                ),
                Expanded(
                  child: files.isEmpty
                    ? Center(child: Text('No editable files found'))
                    : ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          return ListTile(
                            leading: Icon(Icons.insert_drive_file),
                            title: Text(file.name),
                            subtitle: Text(file.size ?? 'Unknown size'),
                            onTap: () {
                              Navigator.of(context).pop();
                              onFileSelected(file.name);
                            },
                          );
                        },
                      ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

### 3. Шаблоны сигналов
```dart
class SignalTemplatesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final templates = [
      {
        'name': 'Garage Door',
        'description': 'Common garage door signal',
        'data': '1010101010101010',
      },
      {
        'name': 'Car Alarm',
        'description': 'Car alarm remote signal',
        'data': '1100110011001100',
      },
      {
        'name': 'Gate Remote',
        'description': 'Gate remote signal',
        'data': '1111000011110000',
      },
    ];
    
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Signal Templates'),
            subtitle: Text('Predefined signal patterns'),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                leading: Icon(Icons.template),
                title: Text(template['name']!),
                subtitle: Text(template['description']!),
                trailing: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _useTemplate(context, template),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _useTemplate(BuildContext context, Map<String, String> template) {
    // Использование шаблона в редакторе
    Navigator.of(context).pop(template['data']);
  }
}
```

### 4. Новый экран EditorScreen
```dart
class EditorScreen extends StatefulWidget {
  final String? initialFile;
  
  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signal Editor'),
        actions: [
          IconButton(
            icon: Icon(Icons.help),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          SignalTemplatesWidget(),
          Expanded(
            child: SignalEditorWidget(
              initialContent: null,
              fileName: widget.initialFile,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editor Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Signal Format:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Binary: 10101010'),
              Text('• Timing: 100 200 100 300'),
              Text('• Hex: 0xAA 0x55'),
              SizedBox(height: 16),
              Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Use spaces to separate timing values'),
              Text('• Use 0 and 1 for binary signals'),
              Text('• Use hex format for complex signals'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

## Задачи для реализации
- [ ] Создать SignalEditorWidget
- [ ] Создать FilePickerDialog
- [ ] Создать SignalTemplatesWidget
- [ ] Создать новый EditorScreen
- [ ] Добавить поддержку различных форматов сигналов
- [ ] Добавить визуализацию сигналов
- [ ] Добавить валидацию сигналов
- [ ] Добавить автосохранение
- [ ] Добавить отмену/повтор операций
- [ ] Добавить поиск и замену в тексте
- [ ] Добавить подсветку синтаксиса
- [ ] Добавить предварительный просмотр
- [ ] Протестировать функциональность редактора
- [ ] Добавить обработку ошибок
- [ ] Добавить справку и примеры

