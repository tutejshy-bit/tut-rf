import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cc1101/cc1101_values.dart';

/// Виджет для предварительного просмотра сигнала
class SignalPreviewWidget extends StatelessWidget {
  final String rawData;
  final double? frequency;
  final String? modulation;
  final double? dataRate;
  final double? deviation;

  const SignalPreviewWidget({
    super.key,
    required this.rawData,
    this.frequency,
    this.modulation,
    this.dataRate,
    this.deviation,
  });

  @override
  Widget build(BuildContext context) {
    if (rawData.trim().isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No signal data to preview',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signal Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Информация о сигнале
            _buildSignalInfo(),
            
            const SizedBox(height: 16),
            
            // Визуализация данных
            _buildDataVisualization(),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalInfo() {
    return Column(
      children: [
        if (frequency != null)
          _buildInfoRow('Frequency', '${frequency!.toStringAsFixed(2)} MHz'),
        if (modulation != null)
          _buildInfoRow('Modulation', modulation!),
        if (dataRate != null)
          _buildInfoRow('Data Rate', '${dataRate!.toStringAsFixed(2)} kBaud'),
        if (deviation != null)
          _buildInfoRow('Deviation', '${deviation!.toStringAsFixed(2)} kHz'),
        _buildInfoRow('Data Length', '${rawData.split(' ').length} samples'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDataVisualization() {
    final samples = rawData.split(' ').where((s) => s.isNotEmpty).toList();
    if (samples.isEmpty) return const SizedBox.shrink();

    // Показываем первые 20 значений
    final displaySamples = samples.take(20).toList();
    final hasMore = samples.length > 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sample Data:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            ...displaySamples.map((sample) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                sample,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            )),
            if (hasMore)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Text(
                  '+${samples.length - 20} more',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Виджет для загрузки файлов
class FileLoadWidget extends StatelessWidget {
  final VoidCallback? onLoadFile;
  final bool enabled;

  const FileLoadWidget({
    super.key,
    this.onLoadFile,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Load Signal File',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: enabled ? onLoadFile : null,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Select File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? () => _showSupportedFormats(context) : null,
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Formats'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            const Text(
              'Supported formats: .sub (FlipperZero), .json (TUT)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportedFormats(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supported File Formats'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FlipperZero SubGhz (.sub)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Raw signal data format\n• Used by Flipper Zero device\n• Contains frequency and modulation settings'),
            
            SizedBox(height: 16),
            
            Text(
              'TUT JSON (.json)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• JSON format with signal parameters\n• Used by TUT (Test & Utility Tool)\n• Contains frequency, data rate, and raw data'),
          ],
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

/// Виджет для отображения статуса передачи
class TransmitStatusWidget extends StatelessWidget {
  final bool isTransmitting;
  final String? statusMessage;
  final int? progress;

  const TransmitStatusWidget({
    super.key,
    required this.isTransmitting,
    this.statusMessage,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isTransmitting 
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isTransmitting ? Icons.send : Icons.pause_circle,
                  color: isTransmitting ? Colors.orange : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTransmitting ? 'Transmitting...' : 'Ready to Transmit',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (statusMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          statusMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (isTransmitting && progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress! / 100.0,
                backgroundColor: Colors.grey.withOpacity(0.3),
              ),
              const SizedBox(height: 8),
              Text('${progress}% complete'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Виджет для валидации конфигурации передачи
class TransmitValidationWidget extends StatelessWidget {
  final List<String> errors;
  final List<String> warnings;

  const TransmitValidationWidget({
    super.key,
    this.errors = const [],
    this.warnings = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty && warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: errors.isNotEmpty 
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  errors.isNotEmpty ? Icons.error : Icons.warning,
                  color: errors.isNotEmpty 
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  errors.isNotEmpty ? 'Validation Errors' : 'Warnings',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: errors.isNotEmpty 
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (errors.isNotEmpty) ...[
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(error)),
                  ],
                ),
              )),
            ],
            
            if (warnings.isNotEmpty) ...[
              ...warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠ ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(warning)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Виджет для отображения истории передач
class TransmitHistoryWidget extends StatelessWidget {
  final List<TransmitHistoryItem> history;

  const TransmitHistoryWidget({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No transmission history',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transmission History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  leading: Icon(
                    item.success ? Icons.check_circle : Icons.error,
                    color: item.success ? Colors.green : Colors.red,
                  ),
                  title: Text('${item.frequency.toStringAsFixed(2)} MHz'),
                  subtitle: Text(
                    '${item.timestamp.toString().substring(11, 19)} • '
                    'Module ${item.module + 1} • '
                    '${item.repeatCount} repeats',
                  ),
                  trailing: Text(
                    item.success ? 'Success' : 'Failed',
                    style: TextStyle(
                      color: item.success ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Элемент истории передачи
class TransmitHistoryItem {
  final DateTime timestamp;
  final double frequency;
  final int module;
  final int repeatCount;
  final bool success;
  final String? errorMessage;

  TransmitHistoryItem({
    required this.timestamp,
    required this.frequency,
    required this.module,
    required this.repeatCount,
    required this.success,
    this.errorMessage,
  });
}






















