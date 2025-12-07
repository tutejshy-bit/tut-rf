import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../services/file_parsers/file_parser_factory.dart';
import '../services/file_parsers/base_file_parser.dart';
import '../services/signal_processing/signal_data.dart';

class FileViewerScreen extends StatefulWidget {
  final dynamic fileItem;
  final String filePath;

  const FileViewerScreen({
    super.key,
    required this.fileItem,
    required this.filePath,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen>
    with TickerProviderStateMixin {
  String? fileContent;
  bool isLoading = false;
  String? errorMessage;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  
  // Парсинг данных
  FileParseResult? parseResult;
  bool hasParser = false;
  String? fileExtension;
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    
    // Определяем расширение файла
    fileExtension = widget.fileItem.name.split('.').last.toLowerCase();
    
    // Начальное количество табов (Raw всегда есть)
    _tabController = TabController(length: 1, vsync: this);
    
    // Откладываем загрузку файла до завершения build
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadFileContent();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFileContent() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
      fileContent = null;
    });

    try {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      
      // Логируем путь к файлу для отладки
      
      // Determine basePath from filePath
      String? basePath;
      String fileName = widget.filePath;
      if (widget.filePath.startsWith('/DATA/SIGNALS/')) {
        basePath = '/DATA/SIGNALS';
        fileName = widget.filePath.substring('/DATA/SIGNALS/'.length);
      } else if (widget.filePath.startsWith('/DATA/RECORDS/')) {
        basePath = '/DATA/RECORDS';
        fileName = widget.filePath.substring('/DATA/RECORDS/'.length);
      }
      
      // Читаем файл с ESP (флаг isLoadingFileContent устанавливается внутри)
      final content = await bleProvider.readFileContent(fileName, basePath: basePath);
      
      if (mounted) {
        // Проверяем, не является ли ответ ошибкой от ESP
        if (content.startsWith('{"type":"error"')) {
          try {
            final errorData = jsonDecode(content);
            setState(() {
              errorMessage = '${errorData['error']}: ${errorData['details']}';
              isLoading = false;
            });
            return;
          } catch (e) {
            // Если не удалось парсить JSON, показываем как есть
          }
        }
        
        // Парсим файл если есть подходящий парсер
        _parseFileContent(content);
        
        setState(() {
          fileContent = content;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  void _parseFileContent(String content) {
    try {
      // Пытаемся найти подходящий парсер
      parseResult = FileParserFactory.parseFile(content, filename: widget.fileItem.name);
      hasParser = parseResult?.success ?? false;
      
      // Обновляем количество табов
      final tabCount = hasParser ? 2 : 1; // Parsed + Raw или только Raw
      if (_tabController.length != tabCount) {
        _tabController.dispose();
        _tabController = TabController(length: tabCount, vsync: this);
      }
    } catch (e) {
      hasParser = false;
      parseResult = null;
    }
  }

  Future<void> _downloadFile() async {
    if (!mounted) return;
    
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      
      // Загружаем файл с ESP
      final content = await bleProvider.downloadFile(
        widget.filePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              downloadProgress = progress;
            });
          }
        },
      );
      
      if (mounted && content != null) {
        // Проверяем, не является ли ответ ошибкой от ESP
        if (content.startsWith('{"type":"error"')) {
          try {
            final errorData = jsonDecode(content);
            throw Exception('${errorData['error']}: ${errorData['details']}');
          } catch (e) {
            // Если не удалось парсить JSON, используем как есть
            throw Exception(content);
          }
        }
        
        // Сохраняем файл на устройство
        await _saveFileToDevice(content);
        
        setState(() {
          isDownloading = false;
          downloadProgress = 0.0;
        });
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showSuccess('File "${widget.fileItem.name}" downloaded successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
          downloadProgress = 0.0;
        });
        
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError('Download failed: $e');
      }
    }
  }

  Future<void> _saveFileToDevice(String content) async {
    try {
      // Получаем путь для сохранения
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file as...',
        fileName: widget.fileItem.name,
        allowedExtensions: null, // Allow any file type
      );
      
      if (outputFile != null) {
        // Создаем файл и записываем содержимое
        final file = File(outputFile);
        await file.writeAsString(content);
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showSuccess('File saved to: ${file.path}');
        }
      } else {
        // Если пользователь отменил сохранение, копируем в буфер обмена
        await Clipboard.setData(ClipboardData(text: content));
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showInfo('File content copied to clipboard');
        }
      }
    } catch (e) {
      // В случае ошибки сохраняем в Downloads или копируем в буфер
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = widget.fileItem.name;
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(content);
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showWarning('File saved to: ${file.path}');
        }
      } catch (e2) {
        // Последний резерв - копируем в буфер обмена
        await Clipboard.setData(ClipboardData(text: content));
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showError('Could not save file. Content copied to clipboard. Error: $e');
        }
      }
    }
  }

  String _getFileExtension() {
    final fileName = widget.fileItem.name;
    final lastDot = fileName.lastIndexOf('.');
    return lastDot != -1 ? fileName.substring(lastDot + 1).toLowerCase() : '';
  }

  bool _isTransmittableFile() {
    final extension = _getFileExtension();
    return extension == 'sub';
  }

  Future<void> _transmitSignal() async {
    if (!mounted) return;
    
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    if (!bleProvider.isConnected) {
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.showError('Not connected to device');
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Transmit Signal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will transmit the signal from this file.'),
            const SizedBox(height: 16),
            Text(
              'File: ${widget.fileItem.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only use in controlled environments. Check local regulations.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.send),
            label: const Text('Transmit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      // Determine basePath based on filePath
      String? basePath;
      String fileName = widget.filePath;
      
      if (widget.filePath.startsWith('/DATA/SIGNALS/')) {
        basePath = '/DATA/SIGNALS';
        fileName = widget.filePath.substring('/DATA/SIGNALS/'.length);
      } else if (widget.filePath.startsWith('/DATA/RECORDS/')) {
        basePath = '/DATA/RECORDS';
        fileName = widget.filePath.substring('/DATA/RECORDS/'.length);
      }
      
      await bleProvider.transmitFromFile(fileName, basePath: basePath);
      
      if (mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showSuccess('Signal transmission started: ${widget.fileItem.name}');
      }
    } catch (e) {
      if (mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError('Transmission failed: $e');
      }
    }
  }

  Widget _buildHexView(String content) {
    final bytes = content.codeUnits;
    final hexLines = <String>[];
    
    for (int i = 0; i < bytes.length; i += 16) {
      final lineBytes = bytes.skip(i).take(16).toList();
      final hexPart = lineBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      final asciiPart = lineBytes
          .map((b) => b >= 32 && b <= 126 ? String.fromCharCode(b) : '.')
          .join('');
      
      hexLines.add('${i.toRadixString(16).padLeft(8, '0')}: $hexPart | $asciiPart');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hexLines.length,
      itemBuilder: (context, index) {
        return SelectableText(
          hexLines[index],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        );
      },
    );
  }

  Widget _buildJsonView(String content) {
    try {
      final jsonData = jsonDecode(content);
      final formattedJson = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          formattedJson,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      );
    } catch (e) {
      return _buildTextView(content);
    }
  }

  Widget _buildTextView(String content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildImageView(String content) {
    // TODO: Implement image preview for supported formats
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Image preview not supported yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(0), // Switch to text view
            child: const Text('View as Text'),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedTab() {
    if (parseResult == null || !parseResult!.success) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to parse file',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (parseResult?.errors.isNotEmpty == true)
            Text(
                parseResult!.errors.first,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final signalData = parseResult!.signalData!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Основные параметры сигнала
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signal Parameters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (signalData.frequency != null)
                    _buildInfoRow('Frequency', '${signalData.frequency!.toStringAsFixed(2)} MHz'),
                  if (signalData.modulation != null)
                    _buildInfoRow('Modulation', signalData.modulation!),
                  if (signalData.dataRate != null)
                    _buildInfoRow('Data Rate', '${signalData.dataRate!.toStringAsFixed(1)} kBaud'),
                  if (signalData.deviation != null)
                    _buildInfoRow('Deviation', '±${signalData.deviation!.toStringAsFixed(1)} kHz'),
                  if (signalData.rxBandwidth != null)
                    _buildInfoRow('RX Bandwidth', '${signalData.rxBandwidth!.toStringAsFixed(1)} kHz'),
                  if (signalData.protocol != null)
                    _buildInfoRow('Protocol', signalData.protocol!),
                  if (signalData.preset != null)
                    _buildInfoRow('Preset', signalData.preset!),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Данные сигнала
          if (signalData.raw != null || signalData.binary != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signal Data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (signalData.samplesCount != null)
                      _buildInfoRow('Samples Count', signalData.samplesCount!.toString()),
                    if (signalData.raw != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Raw Data:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          signalData.raw!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (signalData.binary != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Binary Data:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          signalData.binary!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Предупреждения
          if (parseResult!.warnings.isNotEmpty) ...[
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Warnings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...parseResult!.warnings.map((warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $warning',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexTab() {
    if (fileContent == null) {
      return const Center(
        child: Text('No content available'),
      );
    }
    
    return _buildHexView(fileContent!);
  }

  Widget _buildRawTab() {
    if (fileContent == null) {
      return const Center(
        child: Text('No content available'),
      );
    }
    
    return _buildTextView(fileContent!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48, // Compact toolbar
        title: Row(
          children: [
            Icon(
              widget.fileItem.isDirectory ? Icons.folder : Icons.insert_drive_file,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.fileItem.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (!isLoading && fileContent != null) ...[
            IconButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: fileContent!));
                if (mounted) {
                  final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
                  notificationProvider.showInfo('Content copied to clipboard');
                }
              },
              icon: const Icon(Icons.copy),
              tooltip: 'Copy to Clipboard',
            ),
            IconButton(
              onPressed: isDownloading ? null : _downloadFile,
              icon: isDownloading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: downloadProgress > 0 ? downloadProgress : null,
                      ),
                    )
                  : const Icon(Icons.download),
              tooltip: 'Download File',
            ),
          ],
          // Transmit button for .sub files
          if (_isTransmittableFile())
            IconButton(
              onPressed: isLoading ? null : _transmitSignal,
              icon: const Icon(Icons.send),
              tooltip: 'Transmit Signal',
            ),
          IconButton(
            onPressed: _loadFileContent,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
        bottom: isDownloading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: Container(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: downloadProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              )
            : !isLoading && fileContent != null
                ? TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).colorScheme.onPrimary,
                labelColor: Theme.of(context).colorScheme.onPrimary,
                unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                tabs: hasParser ? [
                  Tab(text: 'Parsed', icon: Icon(Icons.analytics, size: 18)),
                  Tab(text: 'Raw', icon: Icon(Icons.code, size: 18)),
                ] : [
                  Tab(text: 'Raw', icon: Icon(Icons.code, size: 18)),
                ],
                  )
                : null,
      ),
      body: Consumer<BleProvider>(
        builder: (context, bleProvider, _) {
          // Show loading indicator if file is being loaded
          if (isLoading && bleProvider.isLoadingFileContent) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Loading file...'),
                  const SizedBox(height: 8),
                  if (bleProvider.fileContentProgress > 0)
                    Text(
                      '${(bleProvider.fileContentProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (bleProvider.fileContentProgress > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      child: LinearProgressIndicator(
                        value: bleProvider.fileContentProgress,
                      ),
                    ),
                ],
              ),
            );
          }
          
          if (!bleProvider.isConnected) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Not connected to device',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Connect to a device to view files',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: hasParser ? [
              _buildParsedTab(),
              _buildRawTab(),
            ] : [
              _buildRawTab(),
            ],
          );
        },
      ),
    );
  }
}
