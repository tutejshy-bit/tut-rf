import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/log_provider.dart';
import '../widgets/file_list_widget.dart';
import '../widgets/directory_picker_dialog.dart';
import 'file_viewer_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedFiles = <String>{};
  
  @override
  void initState() {
    super.initState();
    // Загружаем список файлов при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      if (bleProvider.isConnected) {
        bleProvider.refreshFileList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        if (!bleProvider.isConnected) {
        return Scaffold(
            body: SafeArea(
              child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Colors.grey,
            ),
                    const SizedBox(height: 16),
            Text(
              'Not connected to device',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            Text(
              'Connect to a device to manage files',
              style: TextStyle(
                        fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
                ),
              ),
        ),
      );
    }

        return Scaffold(
          body: SafeArea(
            child: Column(
      children: [
                // Компактный заголовок с путём и dropdown
                Container(
                  height: 48, // Compact height
                  color: Theme.of(context).colorScheme.inversePrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      // Показываем кнопку "назад" только если мы не в корневой директории
                      if (bleProvider.currentPath != '/' && bleProvider.currentPath.isNotEmpty)
                        IconButton(
                          onPressed: () => bleProvider.navigateUp(),
                          icon: const Icon(Icons.arrow_back),
                          iconSize: 20,
                        ),
                      Expanded(
                        child: _buildPathWithDropdown(context, bleProvider),
                      ),
                    ],
                  ),
                ),
                // Панель с кнопками
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (bleProvider.isLoadingFiles)
                        IconButton(
                          onPressed: () => bleProvider.resetFileLoadingState(),
                          icon: const Icon(Icons.stop),
                          iconSize: 20,
                          tooltip: 'Stop Loading',
                          color: Colors.red,
                        )
                      else
                        IconButton(
                          onPressed: () => bleProvider.refreshFileList(forceRefresh: true),
                          icon: const Icon(Icons.refresh),
                          iconSize: 20,
                          tooltip: 'Refresh',
                        ),
                      IconButton(
                        onPressed: () => _showCreateDirectoryDialog(context, bleProvider),
                        icon: const Icon(Icons.create_new_folder),
                        iconSize: 20,
                        tooltip: 'Create Directory',
                      ),
                      IconButton(
                        onPressed: () => _uploadFileFromDevice(context, bleProvider),
                        icon: const Icon(Icons.upload_file),
                        iconSize: 20,
                        tooltip: 'Upload File',
                      ),
                      IconButton(
                        onPressed: () => _toggleMultiSelectMode(),
                        icon: Icon(_isMultiSelectMode ? Icons.checklist : Icons.checklist_outlined),
                        iconSize: 20,
                        tooltip: _isMultiSelectMode ? 'Exit Multi-Select' : 'Multi-Select',
                      ),
                    ],
                  ),
                ),
                // Список файлов
                Expanded(
                  child: FileListWidget(
                    files: bleProvider.fileList,
                    mode: _isMultiSelectMode ? FileListMode.multiSelect : FileListMode.browse,
                    currentPath: bleProvider.currentPath,
                    currentPathType: bleProvider.currentPathType,
                    showActions: true,
                    showHeader: false,  // Hide the "SD Card" header
                    isLoading: bleProvider.isLoadingFiles,
                    onRefresh: () => bleProvider.refreshFileList(forceRefresh: true),
                    onNavigateUp: () => bleProvider.navigateUp(),
                    onFileSelected: (file) => _handleFileSelection(context, file, bleProvider),
                    onFileAction: (file, action) => _handleFileAction(context, file, action, bleProvider),
                    onMultiSelectAction: (files) => _handleMultiSelectAction(context, files, 'delete', bleProvider),
                    isMultiSelectMode: _isMultiSelectMode,
                    selectedFiles: _selectedFiles,
                    onFileSelectionChanged: (fileName) => _toggleFileSelection(fileName),
                  ),
                ),
                // Панель действий для множественного выбора
                if (_isMultiSelectMode && _selectedFiles.isNotEmpty)
                  _buildMultiSelectActionBar(context),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleFileSelection(BuildContext context, dynamic file, BleProvider bleProvider) {
    if (_isMultiSelectMode && !file.isDirectory) {
      // Toggle selection in multi-select mode
      _toggleFileSelection(file.name);
    } else if (file.isDirectory) {
      bleProvider.navigateToDirectory(file.name);
    } else {
      // Формируем полный путь к файлу с учетом текущей директории
      String fullPath;
      if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
        fullPath = file.name;
      } else {
        fullPath = '${bleProvider.currentPath}/${file.name}';
      }
      
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FileViewerScreen(
            fileItem: file,
            filePath: fullPath,
          ),
                  ),
      );
    }
  }

  void _handleFileAction(BuildContext context, dynamic file, String action, BleProvider bleProvider) {
    switch (action) {
      case 'navigate':
        if (file.isDirectory) {
          bleProvider.navigateToDirectory(file.name);
        }
        break;
      case 'transmit':
        _transmitFile(context, file, bleProvider);
        break;
      case 'download':
        _downloadFile(context, file, bleProvider);
        break;
      case 'copy':
        _copyFile(context, file, bleProvider);
        break;
      case 'rename':
        _renameFile(context, file, bleProvider);
        break;
      case 'delete':
        _deleteFile(context, file, bleProvider);
        break;
      case 'move':
        _moveFile(context, file, bleProvider);
        break;
  }
  }

  void _transmitFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transmit Signal'),
        content: Text('Do you want to transmit signal from file "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Transmit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Передаем полный путь к файлу
      final fullPath = bleProvider.currentPath == '/' ? file.name : '${bleProvider.currentPath}/${file.name}';
      await bleProvider.transmitFromFile(fullPath);

      if (context.mounted) {
        _showSuccessSnackBar('Signal transmission started: ${file.name}');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar('Transmission failed: $e');
      }
    }
  }

  void _downloadFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    try {
      // Формируем полный путь к файлу с учетом текущей директории
      String fullPath;
      if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
        fullPath = file.name;
      } else {
        fullPath = '${bleProvider.currentPath}/${file.name}';
      }
      
      // Загружаем файл с ESP
      final content = await bleProvider.downloadFile(fullPath);
      
      if (content != null && context.mounted) {
        // Сохраняем файл на устройство
        await _saveFileToDevice(context, content, file.name);
      } else if (context.mounted) {
        _showErrorSnackBar('Download failed: No content received');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar('Download failed: $e');
      }
    }
  }

  Future<void> _saveFileToDevice(BuildContext context, String content, String fileName) async {
    try {
      // Сначала пытаемся сохранить в Downloads
      Directory? downloadsDir;
      try {
        // Для Android используем getExternalStorageDirectory + /Download
        // Для iOS используем getApplicationDocumentsDirectory
        if (Platform.isAndroid) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Получаем родительскую директорию (обычно /storage/emulated/0)
            final parentDir = externalDir.parent;
            downloadsDir = Directory('${parentDir.path}/Download');
            // Создаем директорию если не существует
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
          }
        } else {
          // Для iOS используем Documents
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        // Fallback на Documents если не удалось получить Downloads
        downloadsDir = await getApplicationDocumentsDirectory();
      }
      
      if (downloadsDir != null) {
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsString(content);
        
        if (context.mounted) {
          _showSuccessSnackBar('File saved to Downloads: $fileName');
        }
      } else {
        throw Exception('Could not determine download directory');
      }
    } catch (e) {
      // В случае ошибки пытаемся через FilePicker
      try {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save file as...',
          fileName: fileName,
          allowedExtensions: null,
        );
        
        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(content);
          
          if (context.mounted) {
            _showSuccessSnackBar('File saved to: ${file.path}');
          }
        } else {
          // Если пользователь отменил, копируем в буфер обмена
          await Clipboard.setData(ClipboardData(text: content));
          
          if (context.mounted) {
            _showInfoSnackBar('File content copied to clipboard');
          }
        }
      } catch (e2) {
        // Последняя попытка - копируем в буфер обмена
        await Clipboard.setData(ClipboardData(text: content));
        
        if (context.mounted) {
          _showInfoSnackBar('File content copied to clipboard');
        }
      }
    }
  }

  void _copyFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    // First select destination directory
    final directoryResult = await showDirectoryPickerDialog(
      context,
      'Copy File',
      bleProvider,
    );

    if (directoryResult == null) return;

    final destinationPath = directoryResult['path'] as String;
    
    // Then get new file name
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: file.name);
        return AlertDialog(
          title: const Text('Copy File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Destination: $destinationPath'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'New file name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Copy'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        // Формируем полный путь к файлу с учетом текущей директории
        String fullPath;
        if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
          fullPath = file.name;
        } else {
          fullPath = '${bleProvider.currentPath}/${file.name}';
        }
        
        // Формируем путь назначения с новым именем
        // destinationPath уже содержит полный путь из directoryResult
        String destPath = destinationPath;
        if (!destPath.endsWith('/')) {
          destPath = '$destPath/';
        }
        destPath = '$destPath$newName';
        
        // Убираем ведущий слеш если есть (для относительного пути)
        if (destPath.startsWith('/')) {
          destPath = destPath.substring(1);
        }
        
        await bleProvider.copyFile(fullPath, destPath);
        if (context.mounted) {
          _showSuccessSnackBar('File copied: $newName');
          // refreshFileList is already called in copyFile if needed
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar('Copy failed: $e');
        }
      }
    }
  }

  void _renameFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: file.name);
        return AlertDialog(
          title: Text(file.isDirectory ? 'Rename Directory' : 'Rename File'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: file.isDirectory ? 'New directory name' : 'New file name',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != file.name) {
      try {
        // Формируем полный путь к файлу с учетом текущей директории
        String fullPath;
        if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
          fullPath = file.name;
        } else {
          fullPath = '${bleProvider.currentPath}/${file.name}';
        }
        
        final success = await bleProvider.renameFile(fullPath, newName);
        if (context.mounted) {
          if (success) {
            // Обновляем список файлов
            await bleProvider.refreshFileList(forceRefresh: true);
            
            // Если переименована директория, в которой мы находимся, обновляем путь
            if (file.isDirectory) {
              final currentPath = bleProvider.currentPath;
              if (currentPath.endsWith('/${file.name}')) {
                // Мы находимся внутри переименованной директории
                final pathParts = currentPath.split('/');
                pathParts[pathParts.length - 1] = newName;
                // Обновляем путь через навигацию - это проще чем менять напрямую
                // Пусть пользователь сам обновит через refresh
              } else if (currentPath == '/${file.name}' || currentPath == file.name) {
                // Мы находимся в корне переименованной директории
                // В этом случае нужно перейти вверх
                bleProvider.navigateUp();
              }
            }
            
            _showSuccessSnackBar('${file.isDirectory ? 'Directory' : 'File'} renamed to: $newName');
          } else {
            _showErrorSnackBar('Rename failed: ${file.isDirectory ? 'Directory' : 'File'} could not be renamed');
          }
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar('Rename failed: $e');
        }
      }
    }
  }

  void _deleteFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.isDirectory ? 'Delete Directory' : 'Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
        ),
      );

    if (confirmed == true) {
      try {
        // Формируем полный путь к файлу с учетом текущей директории
        String fullPath;
        if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
          fullPath = file.name;
    } else {
          fullPath = '${bleProvider.currentPath}/${file.name}';
        }
        
        await bleProvider.deleteFile(fullPath);
        if (context.mounted) {
          _showSuccessSnackBar('${file.isDirectory ? 'Directory' : 'File'} deleted: ${file.name}');
          await bleProvider.refreshFileList(forceRefresh: true);
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar('Delete failed: $e');
        }
      }
    }
  }

  void _moveFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    final result = await showDirectoryPickerDialog(
      context,
      file.isDirectory ? 'Move Directory' : 'Move File',
      bleProvider,
    );

    if (result != null && result['path'] != null) {
      final destinationPath = result['path'] as String;
      final pathType = result['pathType'] as int;

      try {
        // Формируем полный путь к файлу с учетом текущей директории
        String sourcePath;
        if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
          sourcePath = file.name;
        } else {
          sourcePath = '${bleProvider.currentPath}/${file.name}';
        }
        
        // Формируем путь назначения
        String destPath = destinationPath;
        if (!destPath.endsWith('/')) {
          destPath = '$destPath/';
        }
        destPath = '$destPath${file.name}';
        
        // Move file requires same pathType, so we use current pathType
        final success = await bleProvider.moveFile(sourcePath, destPath);
        if (context.mounted) {
          if (success) {
            _showSuccessSnackBar('${file.isDirectory ? 'Directory' : 'File'} moved: ${file.name}');
            await bleProvider.refreshFileList(forceRefresh: true);
          } else {
            _showErrorSnackBar('Move failed: ${file.name}');
          }
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar('Move failed: $e');
        }
      }
    }
  }

  void _handleMultiSelectAction(BuildContext context, List<dynamic> files, String action, BleProvider bleProvider) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Files'),
          content: Text('Are you sure you want to delete ${files.length} files?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        int successCount = 0;
        int failCount = 0;
        
        for (final file in files) {
          try {
            await bleProvider.deleteFile(file.name);
            successCount++;
          } catch (e) {
            failCount++;
            print('Failed to delete ${file.name}: $e');
          }
        }
        
        // Принудительно обновляем список файлов
        await bleProvider.refreshFileList(forceRefresh: true);
        
        if (context.mounted) {
          _showSuccessSnackBar('Deleted $successCount files${failCount > 0 ? ', $failCount failed' : ''}');
          
          // Сбрасываем выделение только после успешного завершения удаления
          setState(() {
            _selectedFiles.clear();
            _isMultiSelectMode = false;
          });
        }
      }
    }
  }

  Widget _buildMultiSelectActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedFiles.length} selected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedFiles.clear();
              });
            },
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Selection',
            iconSize: 20,
          ),
          IconButton(
            onPressed: () {
              _handleMultiSelectAction(context, _selectedFileObjects, 'delete', Provider.of<BleProvider>(context, listen: false));
              // НЕ сбрасываем выделение здесь - это будет сделано в _handleMultiSelectAction после успешного удаления
            },
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Selected',
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedFiles.clear();
      }
    });
  }

  void _toggleFileSelection(String fileName) {
    setState(() {
      if (_selectedFiles.contains(fileName)) {
        _selectedFiles.remove(fileName);
      } else {
        _selectedFiles.add(fileName);
      }
    });
  }

  List<dynamic> get _selectedFileObjects {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    return bleProvider.fileList.where((file) => _selectedFiles.contains(file.name)).toList();
  }

  void _showSuccessSnackBar(String message) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.showSuccess(message);
  }

  void _showErrorSnackBar(String message) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.showError(message);
  }

  void _showInfoSnackBar(String message) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.showInfo(message);
  }

  String _getPathTypeName(int pathType) {
    switch (pathType) {
      case 0:
        return 'Records';
      case 1:
        return 'Signals';
      case 2:
        return 'Presets';
      case 3:
        return 'Temp';
      default:
        return 'Unknown';
    }
  }

  Widget _buildPathWithDropdown(BuildContext context, BleProvider bleProvider) {
    final pathTypeName = _getPathTypeName(bleProvider.currentPathType);
    final currentPath = bleProvider.currentPath;
    
    // Получаем путь без корневой директории
    String pathWithoutRoot = currentPath;
    if (pathWithoutRoot.startsWith('/')) {
      pathWithoutRoot = pathWithoutRoot.substring(1);
    }
    
    return Row(
      children: [
        // Кликабельная корневая директория с dropdown
        PopupMenuButton<int>(
          icon: Text(
            pathTypeName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
          onSelected: (int selectedType) {
            if (selectedType != bleProvider.currentPathType) {
              bleProvider.switchPathType(selectedType);
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<int>(
              value: 0,
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 20),
                  const SizedBox(width: 8),
                  const Text('Records'),
                  if (bleProvider.currentPathType == 0)
                    const Spacer(),
                  if (bleProvider.currentPathType == 0)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Row(
                children: [
                  const Icon(Icons.signal_cellular_alt, size: 20),
                  const SizedBox(width: 8),
                  const Text('Signals'),
                  if (bleProvider.currentPathType == 1)
                    const Spacer(),
                  if (bleProvider.currentPathType == 1)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: Row(
                children: [
                  const Icon(Icons.settings, size: 20),
                  const SizedBox(width: 8),
                  const Text('Presets'),
                  if (bleProvider.currentPathType == 2)
                    const Spacer(),
                  if (bleProvider.currentPathType == 2)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
            PopupMenuItem<int>(
              value: 3,
              child: Row(
                children: [
                  const Icon(Icons.timer, size: 20),
                  const SizedBox(width: 8),
                  const Text('Temp'),
                  if (bleProvider.currentPathType == 3)
                    const Spacer(),
                  if (bleProvider.currentPathType == 3)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
          ],
        ),
        // Разделитель и путь
        Text(
          '/',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (pathWithoutRoot.isNotEmpty)
          Expanded(
            child: Text(
              pathWithoutRoot,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Future<void> _showCreateDirectoryDialog(BuildContext context, BleProvider bleProvider) async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Directory'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Directory name',
            border: OutlineInputBorder(),
            hintText: 'Enter directory name',
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Формируем полный путь для создания директории
        String fullPath;
        if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
          fullPath = result;
        } else {
          fullPath = '${bleProvider.currentPath}/$result';
        }
        
        await bleProvider.createDirectory(fullPath);
        
        if (context.mounted) {
          _showSuccessSnackBar('Directory created: $result');
          // Обновляем список файлов
          await bleProvider.refreshFileList(forceRefresh: true);
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar('Failed to create directory: $e');
        }
      }
    }
  }

  Future<void> _uploadFileFromDevice(BuildContext context, BleProvider bleProvider) async {
    try {
      // Выбираем файл с устройства
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final file = File(filePath);
        
        if (!await file.exists()) {
          if (context.mounted) {
            _showErrorSnackBar('Selected file does not exist');
          }
          return;
        }
        
        if (context.mounted) {
          // Показываем диалог прогресса
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Uploading $fileName...'),
                ],
              ),
            ),
          );
        }
        
        try {
          // Используем текущую директорию и pathType
          final currentPath = bleProvider.currentPath;
          final pathType = bleProvider.currentPathType;

          // Формируем полный путь для загрузки
          String targetPath = fileName;
          if (currentPath != '/' && currentPath.isNotEmpty) {
            // Убираем ведущий слеш если есть
            String cleanPath = currentPath.startsWith('/') 
                ? currentPath.substring(1) 
                : currentPath;
            targetPath = '$cleanPath/$fileName';
          }

          // Загружаем файл
          final response = await bleProvider.uploadFile(
            file,
            targetPath,
            pathType: pathType,
            onProgress: (progress) {
              // Можно обновить прогресс в диалоге, но для простоты оставляем как есть
            },
          );

          if (context.mounted) {
            Navigator.of(context).pop(); // Закрываем диалог прогресса

            if (response['success'] == true) {
              _showSuccessSnackBar('File uploaded: $fileName');
              // Обновляем список файлов
              await bleProvider.refreshFileList(forceRefresh: true);
            } else {
              final errorMsg = response['error'] ?? 'Upload failed';
              _showErrorSnackBar('Upload failed: $errorMsg');
            }
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context).pop(); // Закрываем диалог прогресса
            
            final errorMessage = 'Upload failed: $e';
            
            // Логируем в LogProvider для отображения на debug экране
            final logProvider = Provider.of<LogProvider>(context, listen: false);
            logProvider.addErrorLog(errorMessage, details: 'File: $fileName');
            
            // Показываем диалог с полным сообщением
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Upload Error'),
                    ],
                  ),
                  content: Text(errorMessage),
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
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar('Failed to pick file: $e');
      }
    }
  }
}