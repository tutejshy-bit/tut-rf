import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../theme/app_colors.dart';

enum FileListMode {
  browse,           // Просмотр файлов с возможностью действий
  select,           // Выбор файла для просмотра
  selectForTransmit, // Выбор файла для передачи
  selectForPreset,  // Выбор файла для пресета
  local,            // Локальный режим без загрузки с сервера
  multiSelect,     // Множественный выбор файлов
}

class FileListWidget extends StatefulWidget {
  final List<dynamic> files;
  final FileListMode mode;
  final Function(dynamic)? onFileSelected;
  final Function(dynamic, String)? onFileAction; // file, action
  final Function(List<dynamic>)? onMultiSelectAction; // selected files, action
  final String? currentPath;
  final bool showActions;
  final String? filterExtension;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final VoidCallback? onNavigateUp;
  final String? title; // Заголовок для локального режима
  final bool showHeader; // Показывать ли заголовок
  final String? basePath; // Базовый путь для файлов (например, /DATA/SIGNALS)
  final bool isMultiSelectMode; // Режим множественного выбора
  final Set<String> selectedFiles; // Выбранные файлы
  final Function(String)? onFileSelectionChanged; // Callback для изменения выбора
  final int? currentPathType; // Тип пути: 0=RECORDS, 1=SIGNALS, 2=PRESETS, 3=TEMP

  const FileListWidget({
    super.key,
    required this.files,
    this.mode = FileListMode.browse,
    this.onFileSelected,
    this.onFileAction,
    this.onMultiSelectAction,
    this.currentPath,
    this.showActions = true,
    this.filterExtension,
    this.isLoading = false,
    this.onRefresh,
    this.onNavigateUp,
    this.title,
    this.showHeader = true,
    this.basePath,
    this.isMultiSelectMode = false,
    this.selectedFiles = const {},
    this.onFileSelectionChanged,
    this.currentPathType,
  });

  @override
  State<FileListWidget> createState() => _FileListWidgetState();
}

class _FileListWidgetState extends State<FileListWidget> {
  // Удаляем локальное состояние, используем переданные параметры
  // final Set<String> _selectedFiles = <String>{};
  // bool _isMultiSelectMode = false;

  List<dynamic> get _filteredFiles {
    if (widget.filterExtension == null) {
      return widget.files;
    }
    
    return widget.files.where((file) {
      final fileName = file.name;
      final extension = fileName.split('.').last.toLowerCase();
      return extension == widget.filterExtension!.toLowerCase();
    }).toList();
  }

  List<dynamic> get _sortedFiles {
    final sortedFiles = List.from(_filteredFiles);
    sortedFiles.sort((a, b) {
      // Сначала директории, потом файлы
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      
      // Если оба одного типа, сортируем по имени
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sortedFiles;
  }

  @override
  Widget build(BuildContext context) {
    // Для local mode используем более темный фон
    final cardColor = widget.mode == FileListMode.local 
        ? AppColors.primaryBackground 
        : Theme.of(context).cardTheme.color;
    
    return Card(
      elevation: widget.showHeader ? 1 : 0,  // Remove elevation if header is hidden
      margin: widget.showHeader ? null : EdgeInsets.zero,  // Remove margin if header is hidden
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (widget.showHeader && (widget.currentPath != null || widget.title != null)) 
            _buildHeader(),
          
          // File List
          Expanded(
            child: widget.isLoading
                    ?           Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.loadingFiles),
                          ],
                        ),
                      )
                : widget.onRefresh != null
                    ? RefreshIndicator(
                        onRefresh: () async {
                          widget.onRefresh!();
                          // Даем время для обновления состояния
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: _sortedFiles.isEmpty
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  child: _buildEmptyState(),
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _sortedFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _sortedFiles[index];
                                  return _buildFileItem(context, file);
                                },
                              ),
                      )
                    : (_sortedFiles.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _sortedFiles.length,
                            itemBuilder: (context, index) {
                              final file = _sortedFiles[index];
                              return _buildFileItem(context, file);
                            },
                          )),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.mode == FileListMode.local ? Icons.radio_button_checked : Icons.folder,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: widget.mode == FileListMode.local ? null : () => _showFullPath(context),
              child: Text(
                widget.mode == FileListMode.local 
                    ? (widget.title ?? 'Files')
                    : 'SD Card: ${widget.currentPath ?? '/'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (widget.mode != FileListMode.local) ...[
            if (widget.currentPath != '/' && widget.onNavigateUp != null)
              IconButton(
                onPressed: widget.isLoading ? null : widget.onNavigateUp,
                icon: const Icon(Icons.arrow_upward, color: AppColors.primaryText),
                tooltip: 'Go Up',
                iconSize: 20,
              ),
            if (widget.onRefresh != null)
              IconButton(
                onPressed: widget.isLoading ? null : widget.onRefresh,
                icon: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: AppColors.primaryText),
                tooltip: 'Refresh',
                iconSize: 20,
              ),
            // Multi-select mode toggle
            IconButton(
              onPressed: widget.isLoading ? null : _toggleMultiSelectMode,
              icon: Icon(
                widget.isMultiSelectMode ? Icons.checklist : Icons.checklist_outlined,
                color: AppColors.primaryText,
              ),
              tooltip: widget.isMultiSelectMode ? 'Exit Multi-Select' : 'Multi-Select',
              iconSize: 20,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.mode == FileListMode.local ? Icons.folder_open : Icons.folder_open,
            size: 64,
            color: AppColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
                widget.mode == FileListMode.local ? AppLocalizations.of(context)!.noRecordedFiles : AppLocalizations.of(context)!.noFilesFound,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.mode == FileListMode.local
                ? AppLocalizations.of(context)!.startRecordingToCaptureSignals
                : widget.mode == FileListMode.browse 
                    ? 'Connect to device to see files'
                    : 'No files available for selection',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, dynamic file) {
    final isSelectable = widget.mode != FileListMode.browse && widget.mode != FileListMode.local;
    final canTransmit = _isTransmittableFile(file.name);
    final isSelected = widget.selectedFiles.contains(file.name);
    
    // Получаем время создания файла
    String? fileTime;
    String? fileDate;
    
    // Сначала проверяем dateCreated из FileItem (безопасный доступ)
    DateTime? dateCreated;
    try {
      dateCreated = file.dateCreated as DateTime?;
    } catch (e) {
      // Если поле dateCreated не существует, используем null
      dateCreated = null;
    }
    
    if (dateCreated != null) {
      final date = dateCreated;
      final now = DateTime.now();
      final difference = now.difference(date);
      
      // Форматируем дату в зависимости от давности
      if (difference.inDays == 0) {
        // Сегодня - показываем только время
        fileTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        // На этой неделе - показываем день недели и время
        final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
        fileDate = '$weekday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        // Старше недели - показываем дату и время
        fileDate = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
                   '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } else if (widget.mode == FileListMode.local) {
      // Fallback: попробуем найти время создания файла из BleProvider
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      final runtimeFiles = bleProvider.recordedRuntimeFiles;
      for (final runtimeFile in runtimeFiles) {
        final fileName = runtimeFile['filename']?.toString() ?? runtimeFile.toString();
        
        if (fileName == file.name && runtimeFile.containsKey('date')) {
          final dateStr = runtimeFile['date'].toString();
          try {
            final date = DateTime.parse(dateStr);
            fileTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          } catch (e) {
            fileTime = null;
          }
          break;
        }
      }
    }
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: file.isDirectory 
          ? SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.folder,
                color: AppColors.primaryText,
                size: 24,
              ),
              )
          : Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _getFileIcon(file.name),
      ),
      title: Text(
        file.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13, // Уменьшенный шрифт
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: file.isDirectory 
          ? null
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (file.isFile && file.size > 0)
            Text(
              file.sizeFormatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
                if (fileDate != null)
                  Text(
                    fileDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                    ),
                  )
                else if (fileTime != null)
            Text(
              fileTime,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText,
                fontSize: 10,
              ),
            ),
        ],
      ),
      trailing: _buildTrailingActions(file, canTransmit, isSelectable),
      onTap: () => _handleFileTap(file),
      onLongPress: widget.showActions ? () => _showContextMenu(file) : null,
    );
  }

  Widget? _buildTrailingActions(dynamic file, bool canTransmit, bool isSelectable) {
    if (file.isDirectory) {
      return Icon(
        Icons.chevron_right,
        color: AppColors.secondaryText,
      );
    }

    // В режиме множественного выбора показываем галочку справа
    if (widget.isMultiSelectMode) {
      final isSelected = widget.selectedFiles.contains(file.name);
      return IconButton(
        icon: Icon(
          isSelected ? Icons.check_circle : Icons.check_circle_outline,
          color: isSelected ? AppColors.primaryAccent : AppColors.primaryText,
        ),
        onPressed: () => _toggleFileSelection(file.name),
        tooltip: isSelected ? 'Deselect file' : 'Select file',
        iconSize: 20,
      );
    }

    if (isSelectable) {
      return IconButton(
        icon: const Icon(Icons.check_circle_outline, color: AppColors.primaryText),
        onPressed: () => widget.onFileSelected?.call(file),
        tooltip: 'Select file',
        iconSize: 20,
      );
    }

     if (canTransmit && (widget.mode == FileListMode.browse || widget.mode == FileListMode.local)) {
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           // Кнопка сохранения (для локальных файлов или TEMP директории, pathType == 3)
           if (widget.mode == FileListMode.local || widget.currentPathType == 3)
             IconButton(
               icon: const Icon(Icons.save),
               onPressed: () => widget.onFileAction?.call(file, 'save_to_signals'),
               tooltip: 'Save to Signals',
               iconSize: 18,
             ),
           // Кнопка отправки
           IconButton(
             icon: const Icon(Icons.send),
             onPressed: () => widget.onFileAction?.call(file, 'transmit'),
             tooltip: 'Transmit Signal',
             iconSize: 18,
           ),
         ],
       );
     }

    return null;
  }

  void _handleFileTap(dynamic file) {
    if (widget.isMultiSelectMode && !file.isDirectory) {
      // Toggle selection in multi-select mode
      _toggleFileSelection(file.name);
    } else if (file.isDirectory && widget.mode != FileListMode.local) {
      // Navigate to directory (only in browse mode)
      widget.onFileAction?.call(file, 'navigate');
    } else {
      if (widget.mode == FileListMode.browse || widget.mode == FileListMode.local) {
        // Open file for viewing
        widget.onFileSelected?.call(file);
      } else {
        // Select file
        widget.onFileSelected?.call(file);
      }
    }
  }

  void _showContextMenu(dynamic file) {
    if (!widget.showActions) return;
    
    if (file.isDirectory) {
      _showDirectoryContextMenu(file);
      return;
    }

    // Для режима local (экран записи) показываем только view/save/transmit
    final isRecordScreen = widget.mode == FileListMode.local;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              file.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            if (isRecordScreen) ...[
              // Для экрана записи: только view/save/transmit
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactActionButton(
                    context,
                    icon: Icons.visibility,
                    label: AppLocalizations.of(context)!.view,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onFileSelected?.call(file);
                    },
                  ),
                  if (_isTransmittableFile(file.name))
                    _buildCompactActionButton(
                      context,
                      icon: Icons.save,
                      label: AppLocalizations.of(context)!.save,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onFileAction?.call(file, 'save_to_signals');
                      },
                    ),
                  if (_isTransmittableFile(file.name))
                    _buildCompactActionButton(
                      context,
                      icon: Icons.send,
                      label: AppLocalizations.of(context)!.transmitSignal,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onFileAction?.call(file, 'transmit');
                      },
                    ),
                ],
              ),
            ] else ...[
              // Для других экранов: все действия
              // Основные действия в одной строке
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_isTransmittableFile(file.name))
                    _buildCompactActionButton(
                      context,
                      icon: Icons.send,
                      label: AppLocalizations.of(context)!.send,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onFileAction?.call(file, 'transmit');
                      },
                    ),
                  if ((widget.mode == FileListMode.local || widget.currentPathType == 3) && _isTransmittableFile(file.name))
                    _buildCompactActionButton(
                      context,
                      icon: Icons.save,
                      label: AppLocalizations.of(context)!.save,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onFileAction?.call(file, 'save_to_signals');
                      },
                    ),
                  _buildCompactActionButton(
                    context,
                    icon: Icons.delete,
                    label: AppLocalizations.of(context)!.delete,
                    isDestructive: true,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onFileAction?.call(file, 'delete');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Дополнительные действия
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactActionButton(
                    context,
                    icon: Icons.visibility,
                    label: AppLocalizations.of(context)!.view,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onFileSelected?.call(file);
                    },
                  ),
                  _buildCompactActionButton(
                    context,
                    icon: Icons.download,
                    label: AppLocalizations.of(context)!.downloadFile,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onFileAction?.call(file, 'download');
                    },
                  ),
                  _buildCompactActionButton(
                    context,
                    icon: Icons.copy,
                    label: AppLocalizations.of(context)!.copyFile,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onFileAction?.call(file, 'copy');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Действия с перемещением
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactActionButton(
                    context,
                    icon: Icons.drive_file_rename_outline,
                    label: AppLocalizations.of(context)!.renameFile,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onFileAction?.call(file, 'rename');
                    },
                  ),
                  _buildCompactActionButton(
                    context,
                    icon: Icons.drive_file_move,
                    label: AppLocalizations.of(context)!.moveFile,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onFileAction?.call(file, 'move');
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDirectoryContextMenu(dynamic directory) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              directory.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // Действия для директории
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactActionButton(
                  context,
                  icon: Icons.drive_file_rename_outline,
                  label: AppLocalizations.of(context)!.renameDirectory,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onFileAction?.call(directory, 'rename');
                  },
                ),
                _buildCompactActionButton(
                  context,
                  icon: Icons.delete,
                  label: AppLocalizations.of(context)!.delete,
                  isDestructive: true,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onFileAction?.call(directory, 'delete');
                  },
                ),
                _buildCompactActionButton(
                  context,
                  icon: Icons.drive_file_move,
                  label: AppLocalizations.of(context)!.moveDirectory,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onFileAction?.call(directory, 'move');
                     },
                   ),
                 ],
               ),
             ],
           ),
         ),
       );
  }

  Widget _buildCompactActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: isDestructive 
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.primaryAccent.withValues(alpha: 0.1),
            foregroundColor: isDestructive 
                ? AppColors.error
                : AppColors.primaryAccent,
          ),
          iconSize: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: isDestructive 
                ? AppColors.error
                : AppColors.primaryText,
          ),
        ),
      ],
    );
  }
  

  void _showFullPath(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Full Path',
          style: TextStyle(color: AppColors.primaryText),
        ),
        content: SelectableText(
          widget.currentPath ?? '/',
          style: const TextStyle(color: AppColors.primaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'sub':
        return ColorFiltered(
          colorFilter: ColorFilter.mode(AppColors.primaryText, BlendMode.srcIn),
          child: Image.asset(
            'assets/images/flipper_subghz.png',
            width: 20,
            height: 20,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.folder,
                color: AppColors.primaryText,
                size: 20,
              );
            },
          ),
        );
      case 'txt':
      case 'log':
        return Icon(
          Icons.description,
          color: AppColors.primaryText,
          size: 20,
        );
      case 'json':
        return Icon(
          Icons.code,
          color: AppColors.primaryText,
          size: 20,
        );
      case 'bin':
      case 'hex':
        return Icon(
          Icons.memory,
          color: AppColors.primaryText,
          size: 20,
        );
      case 'wav':
      case 'mp3':
        return Icon(
          Icons.audiotrack,
          color: AppColors.primaryText,
          size: 20,
        );
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icon(
          Icons.image,
          color: AppColors.primaryText,
          size: 20,
        );
      case 'zip':
      case 'rar':
        return Icon(
          Icons.archive,
          color: AppColors.primaryText,
          size: 20,
        );
      default:
        return Icon(
          Icons.insert_drive_file,
          color: AppColors.primaryText,
          size: 20,
        );
    }
  }

  bool _isTransmittableFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return extension == 'sub';
  }

  void _toggleMultiSelectMode() {
    // Теперь это просто callback, состояние управляется родительским виджетом
    // Этот метод может быть удален, так как кнопка теперь в FilesScreen
  }

  void _toggleFileSelection(String fileName) {
    // Используем callback для уведомления родительского виджета
    widget.onFileSelectionChanged?.call(fileName);
  }


}

