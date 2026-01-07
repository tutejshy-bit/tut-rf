import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/log_provider.dart';
import '../widgets/file_list_widget.dart';
import '../widgets/directory_picker_dialog.dart';
import '../widgets/transmit_file_dialog.dart';
import '../theme/app_colors.dart';
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
              color: AppColors.secondaryText,
            ),
                    const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.notConnectedToDevice,
              style: TextStyle(
                fontSize: 18,
                color: AppColors.secondaryText,
              ),
            ),
            Text(
              AppLocalizations.of(context)!.connectToDeviceToManageFiles,
              style: TextStyle(
                        fontSize: 14,
                color: AppColors.secondaryText,
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
                  color: AppColors.secondaryBackground,
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
                          tooltip: AppLocalizations.of(context)!.stopLoading,
                          color: AppColors.error,
                        )
                      else
                        IconButton(
                          onPressed: () => bleProvider.refreshFileList(forceRefresh: true),
                          icon: const Icon(Icons.refresh),
                          iconSize: 20,
                          tooltip: AppLocalizations.of(context)!.refresh,
                        ),
                      IconButton(
                        onPressed: () => _showCreateDirectoryDialog(context, bleProvider),
                        icon: const Icon(Icons.create_new_folder),
                        iconSize: 20,
                        tooltip: AppLocalizations.of(context)!.createDirectory,
                      ),
                      IconButton(
                        onPressed: () => _uploadFileFromDevice(context, bleProvider),
                        icon: const Icon(Icons.upload_file),
                        iconSize: 20,
                        tooltip: AppLocalizations.of(context)!.uploadFile,
                      ),
                      IconButton(
                        onPressed: () => _toggleMultiSelectMode(),
                        icon: Icon(_isMultiSelectMode ? Icons.checklist : Icons.checklist_outlined),
                        iconSize: 20,
                        tooltip: _isMultiSelectMode ? AppLocalizations.of(context)!.exitMultiSelect : AppLocalizations.of(context)!.multiSelect,
                      ),
                    ],
                  ),
                ),
                // Полоска с количеством файлов
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _buildFileCountText(bleProvider),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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

  String _buildFileCountText(BleProvider bleProvider) {
    final l10n = AppLocalizations.of(context)!;
    
    // При загрузке показываем "?" вместо предыдущего значения
    if (bleProvider.isLoadingFiles) {
      return l10n.loadingFiles;
    }
    
    final loadedCount = bleProvider.fileList.length;
    final totalCount = bleProvider.totalFilesInDirectory;
    
    if (totalCount > 0) {
      return l10n.filesLoadedCount(loadedCount, totalCount);
    } else if (loadedCount > 0) {
      return l10n.filesInDirectory(loadedCount);
    } else {
      return l10n.noFiles;
    }
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
            pathType: bleProvider.currentPathType,
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
    // Передаем полный путь к файлу
    final fullPath = bleProvider.currentPath == '/' ? file.name : '${bleProvider.currentPath}/${file.name}';
    
    await TransmitFileDialog.showAndTransmit(
      context,
      fileName: file.name,
      filePath: fullPath,
      pathType: bleProvider.currentPathType,
    );
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
        final l10n = AppLocalizations.of(context)!;
        _showErrorSnackBar(l10n.downloadFailedNoContent);
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showErrorSnackBar(l10n.downloadFailed(e.toString()));
      }
    }
  }

  Future<void> _saveFileToDevice(BuildContext context, String content, String fileName) async {
    try {
      // Конвертируем строку в байты для сохранения
      final bytes = Uint8List.fromList(utf8.encode(content));
      print('_saveFileToDevice: Starting save process for file: $fileName, size: ${bytes.length} bytes');
      
      // На Android и iOS FilePicker.saveFile требует передачи байтов
      final l10n = AppLocalizations.of(context)!;
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveFileAs,
        fileName: fileName,
        bytes: bytes, // Передаем байты для Android/iOS
        allowedExtensions: null,
      );
      
      if (outputFile != null && outputFile.isNotEmpty) {
        print('_saveFileToDevice: File saved successfully to: $outputFile');
        
        // Проверяем, что файл действительно существует
        final file = File(outputFile);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('_saveFileToDevice: File verified, size: $fileSize bytes');
          
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            _showSuccessSnackBar(l10n.fileSaved(outputFile));
          }
        } else {
          // На некоторых платформах FilePicker сам сохраняет файл, проверяем через небольшую задержку
          await Future.delayed(const Duration(milliseconds: 100));
          if (await file.exists()) {
            if (context.mounted) {
              final l10n = AppLocalizations.of(context)!;
              _showSuccessSnackBar(l10n.fileSaved(outputFile));
            }
          } else {
            throw Exception('File was not created at path: $outputFile');
          }
        }
      } else {
        print('_saveFileToDevice: User cancelled save dialog, copying to clipboard');
        // Если пользователь отменил, копируем в буфер обмена
        await Clipboard.setData(ClipboardData(text: content));
        
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showInfoSnackBar(l10n.fileContentCopiedToClipboard);
        }
      }
    } catch (e) {
      print('_saveFileToDevice: Error during save: $e');
      // В случае ошибки пытаемся сохранить в Documents как fallback
      try {
        print('_saveFileToDevice: Trying fallback to Documents directory');
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(content);
        
        // Проверяем, что файл действительно сохранен
        if (await file.exists()) {
          final fileSize = await file.length();
          print('_saveFileToDevice: File saved to Documents, size: $fileSize bytes');
          
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            _showSuccessSnackBar(l10n.fileSavedToDocuments(file.path));
          }
        } else {
          throw Exception('File was written but does not exist');
        }
      } catch (e2) {
        print('_saveFileToDevice: Fallback also failed: $e2');
        // Последняя попытка - копируем в буфер обмена
        await Clipboard.setData(ClipboardData(text: content));
        
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorSnackBar(l10n.couldNotSaveFile(e.toString()));
        }
      }
    }
  }

  void _copyFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    // First select destination directory
    final l10n = AppLocalizations.of(context)!;
    final directoryResult = await showDirectoryPickerDialog(
      context,
      l10n.copyFile,
      bleProvider,
    );

    if (directoryResult == null) return;

    final destinationPath = directoryResult['path'] as String;
    
    // Then get new file name
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final controller = TextEditingController(text: file.name);
        return AlertDialog(
          title: Text(
            l10n.copyFile,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.destination(destinationPath),
                style: const TextStyle(color: AppColors.primaryText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: l10n.newFileName,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.copy),
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
          final l10n = AppLocalizations.of(context)!;
          _showSuccessSnackBar(l10n.fileCopied(newName));
          // refreshFileList is already called in copyFile if needed
        }
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorSnackBar(l10n.copyFailed(e.toString()));
        }
      }
    }
  }

  void _renameFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final controller = TextEditingController(text: file.name);
        return AlertDialog(
          title: Text(
            file.isDirectory ? l10n.renameDirectory : l10n.renameFile,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: file.isDirectory ? l10n.newDirectoryName : l10n.newFileName,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.rename),
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
            
            final l10n = AppLocalizations.of(context)!;
            _showSuccessSnackBar(file.isDirectory ? l10n.directoryRenamed(newName) : l10n.fileRenamed(newName));
          } else {
            final l10n = AppLocalizations.of(context)!;
            _showErrorSnackBar(l10n.renameFailed(file.isDirectory ? 'Directory' : 'File'));
          }
        }
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorSnackBar(l10n.renameFailed(e.toString()));
        }
      }
    }
  }

  void _deleteFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(
            file.isDirectory ? l10n.deleteDirectory : l10n.deleteFile,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: Text(
            l10n.deleteConfirm(file.name),
            style: const TextStyle(color: AppColors.primaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
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
          final l10n = AppLocalizations.of(context)!;
          _showSuccessSnackBar(file.isDirectory ? l10n.directoryDeleted(file.name) : l10n.fileDeleted(file.name));
          await bleProvider.refreshFileList(forceRefresh: true);
        }
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorSnackBar(l10n.deleteFailed(e.toString()));
        }
      }
    }
  }

  void _moveFile(BuildContext context, dynamic file, BleProvider bleProvider) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDirectoryPickerDialog(
      context,
      file.isDirectory ? l10n.moveDirectory : l10n.moveFile,
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
        
        // Use current pathType for source, pathType from dialog for destination
        final success = await bleProvider.moveFile(
          sourcePath, 
          destPath, 
          sourcePathType: bleProvider.currentPathType,
          destPathType: pathType,
        );
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          if (success) {
            _showSuccessSnackBar(file.isDirectory ? l10n.directoryMoved(file.name) : l10n.fileMoved(file.name));
            await bleProvider.refreshFileList(forceRefresh: true);
          } else {
            _showErrorSnackBar(l10n.moveFailed(file.name));
          }
        }
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorSnackBar(l10n.moveFailed(e.toString()));
        }
      }
    }
  }

  void _handleMultiSelectAction(BuildContext context, List<dynamic> files, String action, BleProvider bleProvider) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext)!;
          return AlertDialog(
            title: Text(
              l10n.deleteFiles,
              style: const TextStyle(color: AppColors.primaryText),
            ),
            content: Text(
              l10n.deleteFilesConfirm(files.length),
              style: const TextStyle(color: AppColors.primaryText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        int successCount = 0;
        int failCount = 0;
        
        for (final file in files) {
          try {
            // Build full path including current directory
            String fullPath;
            if (bleProvider.currentPath == '/' || bleProvider.currentPath.isEmpty) {
              fullPath = file.name;
            } else {
              fullPath = '${bleProvider.currentPath}/${file.name}';
            }
            await bleProvider.deleteFile(fullPath);
            successCount++;
          } catch (e) {
            failCount++;
            print('Failed to delete ${file.name}: $e');
          }
        }
        
        // Принудительно обновляем список файлов
        await bleProvider.refreshFileList(forceRefresh: true);
        
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          final extra = failCount > 0 ? ', $failCount ${l10n.failed}' : '';
          _showSuccessSnackBar(l10n.deletedFilesCount(successCount, extra));
          
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
            AppLocalizations.of(context)!.selectedCount(_selectedFiles.length),
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
            tooltip: AppLocalizations.of(context)!.clearSelection,
            iconSize: 20,
          ),
          IconButton(
            onPressed: () {
              _handleMultiSelectAction(context, _selectedFileObjects, 'delete', Provider.of<BleProvider>(context, listen: false));
              // НЕ сбрасываем выделение здесь - это будет сделано в _handleMultiSelectAction после успешного удаления
            },
            icon: const Icon(Icons.delete),
            tooltip: AppLocalizations.of(context)!.deleteSelected,
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

  String _getPathTypeName(BuildContext context, int pathType) {
    final l10n = AppLocalizations.of(context)!;
    switch (pathType) {
      case 0:
        return l10n.records;
      case 1:
        return l10n.captured;
      case 2:
        return l10n.presets;
      case 3:
        return l10n.temp;
      default:
        return 'Unknown';
    }
  }

  Widget _buildPathWithDropdown(BuildContext context, BleProvider bleProvider) {
    final pathTypeName = _getPathTypeName(context, bleProvider.currentPathType);
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
              color: AppColors.primaryText,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primaryText.withOpacity(0.7),
            ),
          ),
          onSelected: (int selectedType) {
            if (selectedType != bleProvider.currentPathType) {
              bleProvider.switchPathType(selectedType);
            }
          },
          itemBuilder: (BuildContext menuContext) {
            final l10n = AppLocalizations.of(menuContext)!;
            return [
              PopupMenuItem<int>(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.records,
                      style: const TextStyle(color: AppColors.primaryText),
                    ),
                    if (bleProvider.currentPathType == 0)
                      const Spacer(),
                    if (bleProvider.currentPathType == 0)
                      const Icon(Icons.check, size: 20, color: AppColors.primaryText),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.signal_cellular_alt, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.captured,
                      style: const TextStyle(color: AppColors.primaryText),
                    ),
                    if (bleProvider.currentPathType == 1)
                      const Spacer(),
                    if (bleProvider.currentPathType == 1)
                      const Icon(Icons.check, size: 20, color: AppColors.primaryText),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 2,
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.presets,
                      style: const TextStyle(color: AppColors.primaryText),
                    ),
                    if (bleProvider.currentPathType == 2)
                      const Spacer(),
                    if (bleProvider.currentPathType == 2)
                      const Icon(Icons.check, size: 20, color: AppColors.primaryText),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 3,
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.temp,
                      style: const TextStyle(color: AppColors.primaryText),
                    ),
                    if (bleProvider.currentPathType == 3)
                      const Spacer(),
                    if (bleProvider.currentPathType == 3)
                      const Icon(Icons.check, size: 20, color: AppColors.primaryText),
                  ],
                ),
              ),
            ];
          },
        ),
        // Разделитель и путь
        Text(
          '/',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (pathWithoutRoot.isNotEmpty)
          Expanded(
            child: Text(
              pathWithoutRoot,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primaryText,
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
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(
            l10n.createDirectory,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: l10n.directoryName,
              border: const OutlineInputBorder(),
              hintText: l10n.enterDirectoryName,
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(dialogContext).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(dialogContext).pop(name);
                }
              },
              child: Text(l10n.create),
            ),
          ],
        );
      },
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
          final l10n = AppLocalizations.of(context)!;
          _showSuccessSnackBar(l10n.directoryCreated(result));
          // Обновляем список файлов
          await bleProvider.refreshFileList(forceRefresh: true);
        }
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorSnackBar(l10n.failedToCreateDirectory(e.toString()));
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
            final l10n = AppLocalizations.of(context)!;
            _showErrorSnackBar(l10n.selectedFileDoesNotExist);
          }
          return;
        }
        
        if (context.mounted) {
          // Показываем диалог прогресса
          final l10n = AppLocalizations.of(context)!;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.uploadingFile(fileName)),
                ],
              ),
            ),
          );
        }
        
        try {
          // Используем текущую директорию и pathType
          final currentPath = bleProvider.currentPath;
          final pathType = bleProvider.currentPathType;

          print('Upload: currentPath="$currentPath", pathType=$pathType, fileName="$fileName"');

          // Формируем полный путь для загрузки
          String targetPath = fileName;
          if (currentPath != '/' && currentPath.isNotEmpty) {
            // Убираем ведущий слеш если есть
            String cleanPath = currentPath.startsWith('/') 
                ? currentPath.substring(1) 
                : currentPath;
            targetPath = '$cleanPath/$fileName';
          }

          print('Upload: targetPath="$targetPath"');

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
            final l10n = AppLocalizations.of(context)!;

            if (response['success'] == true) {
              _showSuccessSnackBar(l10n.fileUploaded(fileName));
              // Обновляем список файлов
              await bleProvider.refreshFileList(forceRefresh: true);
            } else {
              final errorMsg = response['error'] ?? l10n.uploadFailed('Unknown error');
              _showErrorSnackBar(l10n.uploadFailed(errorMsg));
            }
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context).pop(); // Закрываем диалог прогресса
            final l10n = AppLocalizations.of(context)!;
            
            final errorMessage = l10n.uploadFailed(e.toString());
            
            // Логируем в LogProvider для отображения на debug экране
            final logProvider = Provider.of<LogProvider>(context, listen: false);
            logProvider.addErrorLog(errorMessage, details: 'File: $fileName');
            
            // Показываем диалог с полным сообщением
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(l10n.uploadError),
                    ],
                  ),
                  content: Text(errorMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(l10n.ok),
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
        final l10n = AppLocalizations.of(context)!;
        _showErrorSnackBar(l10n.failedToPickFile(e.toString()));
      }
    }
  }
}