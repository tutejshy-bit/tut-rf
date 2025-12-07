import 'package:flutter/material.dart';
import '../services/cc1101/cc1101_calculator.dart';

/// Компактный виджет для отображения состояния модулей CC1101
class ModuleStatusWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cc1101Modules;
  final Map<String, dynamic>? deviceInfo;

  const ModuleStatusWidget({
    super.key,
    required this.cc1101Modules,
    this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с информацией об устройстве
            _buildHeader(context),
            const SizedBox(height: 12),
            
            // Информация о модулях
            ...cc1101Modules.asMap().entries.map((entry) {
              final index = entry.key;
              final module = entry.value;
              return _buildModuleCard(context, index, module);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final freeHeap = deviceInfo?['freeHeap'] ?? 0;
    
    return Row(
      children: [
        Icon(
          Icons.memory,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Device Status',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${(freeHeap / 1024).toStringAsFixed(1)} KB',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(BuildContext context, int index, Map<String, dynamic> module) {
    final moduleId = module['id'] ?? index;
    final mode = module['mode'] ?? 'Unknown';
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

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок модуля
          Row(
            children: [
              Icon(
                Icons.radio,
                size: 18,
                color: _getModeColor(context, mode),
              ),
              const SizedBox(width: 8),
              Text(
                'Module $moduleId',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildModeChip(context, mode),
            ],
          ),
          
          if (config != null) ...[
            const SizedBox(height: 8),
            _buildConfigInfo(context, config),
          ] else if (settings.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSettingsError(context, settings),
          ],
        ],
      ),
    );
  }

  Widget _buildModeChip(BuildContext context, String mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getModeColor(context, mode).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mode,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: _getModeColor(context, mode),
        ),
      ),
    );
  }

  Widget _buildConfigInfo(BuildContext context, CC1101Config config) {
    return Column(
      children: [
        // Частота и модуляция
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.signal_cellular_alt,
                '${config.frequency.toStringAsFixed(1)} MHz',
                'Frequency',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.tune,
                config.modulationName,
                'Modulation',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        
        // Data Rate и Bandwidth
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.speed,
                '${(config.dataRate / 1000).toStringAsFixed(1)} kbps',
                'Data Rate',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.signal_cellular_4_bar,
                '${(config.bandwidth / 1000).toStringAsFixed(1)} kHz',
                'Bandwidth',
              ),
            ),
          ],
        ),
        // Deviation для FSK модуляций (2-FSK или GFSK)
        if (config.modulation == 0 || config.modulation == 1) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  Icons.tune,
                  '${(config.deviation / 1000).toStringAsFixed(2)} kHz',
                  'Deviation',
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsError(BuildContext context, String settings) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings Parse Error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                Text(
                  'Raw: ${settings.substring(0, 50)}${settings.length > 50 ? '...' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getModeColor(BuildContext context, String mode) {
    switch (mode.toLowerCase()) {
      case 'idle':
        return Colors.grey;
      case 'record':
      case 'recording':
        return Colors.red;
      case 'transmit':
      case 'transmitting':
        return Colors.green;
      case 'scan':
      case 'scanning':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
