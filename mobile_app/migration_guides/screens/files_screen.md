# Files Screen - Перенос из VueJS

## Описание
Экран файлового менеджера для управления файлами на SD карте ESP32. Позволяет просматривать, загружать, удалять и управлять файлами.

## VueJS версия (PageFiles.vue)

### Основные функции:
1. **Список файлов** - отображение файлов и папок в виде дерева
2. **Навигация** - переход по папкам, возврат наверх
3. **Загрузка файлов** - загрузка файлов на ESP32
4. **Операции с файлами** - переименование, удаление, перемещение
5. **Создание папок** - создание новых директорий

### Ключевые компоненты:
- `FilesList` - основной компонент списка файлов
- `UploadWidget` - виджет загрузки файлов
- Операции с файлами (переименование, удаление, перемещение)

## Текущая Android версия
- Базовая функциональность в `FilesScreen`
- Простое отображение списка файлов
- Навигация по папкам

## Что нужно улучшить

### 1. Улучшенный файловый менеджер
```dart
class EnhancedFileExplorerWidget extends StatefulWidget {
  @override
  _EnhancedFileExplorerWidgetState createState() => _EnhancedFileExplorerWidgetState();
}

class _EnhancedFileExplorerWidgetState extends State<EnhancedFileExplorerWidget> {
  String currentPath = '/';
  List<FileItem> fileList = [];
  bool isLoading = false;
  Set<String> selectedFiles = {};
  
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        return Column(
          children: [
            _buildPathBar(),
            _buildToolbar(),
            Expanded(
              child: _buildFileList(),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildPathBar() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(Icons.folder),
            SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildPathSegments(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildPathSegments() {
    List<String> segments = currentPath.split('/').where((s) => s.isNotEmpty).toList();
    List<Widget> widgets = [];
    
    // Добавляем корневую папку
    widgets.add(
      GestureDetector(
        onTap: () => _navigateToPath('/'),
        child: Text('/', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
    
    // Добавляем сегменты пути
    String currentSegmentPath = '';
    for (int i = 0; i < segments.length; i++) {
      currentSegmentPath += '/${segments[i]}';
      final isLast = i == segments.length - 1;
      
      widgets.add(Text('/'));
      widgets.add(
        GestureDetector(
          onTap: isLast ? null : () => _navigateToPath(currentSegmentPath),
          child: Text(
            segments[i],
            style: TextStyle(
              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              color: isLast ? null : Colors.blue,
            ),
          ),
        ),
      );
    }
    
    return widgets;
  }
  
  Widget _buildToolbar() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _refreshFiles,
            ),
            IconButton(
              icon: Icon(Icons.upload),
              onPressed: _showUploadDialog,
            ),
            IconButton(
              icon: Icon(Icons.create_new_folder),
              onPressed: _showCreateFolderDialog,
            ),
            if (selectedFiles.isNotEmpty) ...[
              Spacer(),
              Text('${selectedFiles.length} selected'),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: _deleteSelectedFiles,
              ),
              IconButton(
                icon: Icon(Icons.move_to_inbox),
                onPressed: _moveSelectedFiles,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (fileList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No files found'),
            SizedBox(height: 8),
            TextButton(
              onPressed: _refreshFiles,
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: fileList.length,
      itemBuilder: (context, index) {
        final file = fileList[index];
        final isSelected = selectedFiles.contains(file.name);
        
        return ListTile(
          leading: _buildFileIcon(file),
          title: Text(file.name),
          subtitle: _buildFileSubtitle(file),
          trailing: _buildFileActions(file),
          selected: isSelected,
          onTap: () => _handleFileTap(file),
          onLongPress: () => _toggleFileSelection(file),
        );
      },
    );
  }
  
  Widget _buildFileIcon(FileItem file) {
    if (file.type == 'directory') {
      return Icon(Icons.folder, color: Colors.blue);
    }
    
    // Определяем иконку по расширению файла
    String extension = file.name.split('.').last.toLowerCase();
    IconData iconData;
    
    switch (extension) {
      case 'sub':
        iconData = Icons.radio;
        break;
      case 'json':
        iconData = Icons.code;
        break;
      case 'txt':
        iconData = Icons.text_snippet;
        break;
      default:
        iconData = Icons.insert_drive_file;
    }
    
    return Icon(iconData);
  }
  
  Widget _buildFileSubtitle(FileItem file) {
    List<String> subtitleParts = [];
    
    if (file.size != null) {
      subtitleParts.add(_formatFileSize(file.size!));
    }
    
    if (file.date != null) {
      subtitleParts.add(file.date!);
    }
    
    return Text(subtitleParts.join(' • '));
  }
  
  Widget _buildFileActions(FileItem file) {
    return PopupMenuButton<String>(
      onSelected: (action) => _handleFileAction(action, file),
      itemBuilder: (context) => [
        if (file.type == 'file') ...[
          PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility),
                SizedBox(width: 8),
                Text('View'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download),
                SizedBox(width: 8),
                Text('Download'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'transmit',
            child: Row(
              children: [
                Icon(Icons.send),
                SizedBox(width: 8),
                Text('Transmit'),
              ],
            ),
          ),
        ],
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
```

### 2. Виджет загрузки файлов
```dart
class FileUploadWidget extends StatefulWidget {
  final String targetPath;
  
  @override
  _FileUploadWidgetState createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  List<File> selectedFiles = [];
  bool isUploading = false;
  double uploadProgress = 0.0;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Files', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            if (selectedFiles.isEmpty)
              _buildFilePicker()
            else
              _buildFileList(),
            SizedBox(height: 16),
            if (isUploading) _buildUploadProgress(),
            _buildUploadActions(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickFiles,
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload, size: 32),
            SizedBox(height: 8),
            Text('Tap to select files'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileList() {
    return Column(
      children: [
        ...selectedFiles.map((file) => ListTile(
          leading: Icon(Icons.insert_drive_file),
          title: Text(file.path.split('/').last),
          subtitle: Text(_formatFileSize(file.lengthSync())),
          trailing: IconButton(
            icon: Icon(Icons.remove_circle),
            onPressed: () => _removeFile(file),
          ),
        )).toList(),
      ],
    );
  }
  
  Widget _buildUploadProgress() {
    return Column(
      children: [
        LinearProgressIndicator(value: uploadProgress),
        SizedBox(height: 8),
        Text('Uploading... ${(uploadProgress * 100).toInt()}%'),
      ],
    );
  }
  
  Widget _buildUploadActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: selectedFiles.isEmpty ? null : _pickFiles,
            child: Text('Add More'),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: selectedFiles.isEmpty || isUploading ? null : _uploadFiles,
            child: Text('Upload'),
          ),
        ),
      ],
    );
  }
}
```

### 3. Диалог просмотра файла
```dart
class FileViewerDialog extends StatefulWidget {
  final String fileName;
  final String filePath;
  
  @override
  _FileViewerDialogState createState() => _FileViewerDialogState();
}

class _FileViewerDialogState extends State<FileViewerDialog> {
  String fileContent = '';
  bool isLoading = true;
  bool isError = false;
  
  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: Text(widget.fileName),
              actions: [
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: _copyToClipboard,
                ),
                IconButton(
                  icon: Icon(Icons.download),
                  onPressed: _downloadFile,
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _transmitFile,
                ),
              ],
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error loading file'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadFileContent,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: SelectableText(
        fileContent,
        style: TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
  
  void _loadFileContent() async {
    try {
      setState(() {
        isLoading = true;
        isError = false;
      });
      
      final content = await context.read<BleProvider>().readFileContent(widget.filePath);
      
      setState(() {
        fileContent = content;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }
  
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: fileContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File content copied to clipboard')),
    );
  }
  
  void _downloadFile() {
    // Реализация скачивания файла
  }
  
  void _transmitFile() {
    context.read<BleProvider>().sendCommand('tx.file ${widget.filePath}');
    Navigator.of(context).pop();
  }
}
```

## Задачи для реализации
- [ ] Улучшить существующий FilesScreen
- [ ] Создать EnhancedFileExplorerWidget
- [ ] Создать FileUploadWidget
- [ ] Создать FileViewerDialog
- [ ] Добавить поддержку множественного выбора файлов
- [ ] Добавить операции с файлами (переименование, удаление, перемещение)
- [ ] Добавить создание папок
- [ ] Добавить drag & drop для загрузки файлов
- [ ] Добавить предварительный просмотр файлов
- [ ] Добавить поиск по файлам
- [ ] Добавить сортировку файлов
- [ ] Добавить кеширование списка файлов
- [ ] Протестировать все операции с файлами
- [ ] Добавить обработку ошибок
- [ ] Добавить подтверждения для опасных операций

