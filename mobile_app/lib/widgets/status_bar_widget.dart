import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36, // Компактный размер (как status bar)
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Левая часть: иконки статуса (5-6 иконок)
          _buildStatusIcons(context),
          
          // Разделитель
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
          
          // Правая часть: область уведомлений
          Expanded(
            child: _buildNotificationArea(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcons(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. BLE Connection Status
              _StatusIcon(
                icon: bleProvider.isConnected 
                    ? Icons.bluetooth_connected 
                    : Icons.bluetooth_disabled,
                color: bleProvider.isConnected 
                    ? Colors.blue 
                    : Colors.grey,
                tooltip: bleProvider.isConnected 
                    ? 'Connected: ${bleProvider.connectedDevice?.platformName ?? "Unknown"}' 
                    : 'Not connected',
              ),
              
              const SizedBox(width: 6),
              
              // 2. Module 0 Status
              if (bleProvider.isConnected && bleProvider.cc1101Modules != null && bleProvider.cc1101Modules!.isNotEmpty)
                _StatusIcon(
                  icon: _getModuleIcon(bleProvider.cc1101Modules![0]['state'] ?? 0),
                  color: _getModuleColor(bleProvider.cc1101Modules![0]['state'] ?? 0),
                  tooltip: 'Module 0: ${_getModuleStateName(bleProvider.cc1101Modules![0]['state'] ?? 0)}',
                  label: '0',
                ),
              
              const SizedBox(width: 6),
              
              // 3. Module 1 Status
              if (bleProvider.isConnected && bleProvider.cc1101Modules != null && bleProvider.cc1101Modules!.length > 1)
                _StatusIcon(
                  icon: _getModuleIcon(bleProvider.cc1101Modules![1]['state'] ?? 0),
                  color: _getModuleColor(bleProvider.cc1101Modules![1]['state'] ?? 0),
                  tooltip: 'Module 1: ${_getModuleStateName(bleProvider.cc1101Modules![1]['state'] ?? 0)}',
                  label: '1',
                ),
              
              const SizedBox(width: 6),
              
              // 4. SD Card Status (always available when connected)
              if (bleProvider.isConnected)
                _StatusIcon(
                  icon: Icons.sd_card,
                  color: Colors.orange,
                  tooltip: 'SD Card ready',
                ),
              
              const SizedBox(width: 6),
              
              // 5. Memory Status
              if (bleProvider.isConnected && bleProvider.freeHeap != null)
                _MemoryStatusIcon(freeHeap: bleProvider.freeHeap!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationArea(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final notification = notificationProvider.currentNotification;
        final hasHistory = notificationProvider.notificationHistory.isNotEmpty;
        
        // Показываем либо текущее уведомление, либо кнопку для просмотра истории
        if (notification == null) {
          if (!hasHistory) {
            return const SizedBox.shrink();
          }
          // Показываем кнопку для просмотра истории
          return InkWell(
            onTap: () => _showNotificationList(context, notificationProvider),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${notificationProvider.notificationHistory.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return InkWell(
          onTap: () => _showNotificationList(context, notificationProvider),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              notification.message,
              style: TextStyle(
                fontSize: 12,
                color: notification.color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  void _showNotificationList(BuildContext context, NotificationProvider notificationProvider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            final hasHistory = provider.notificationHistory.isNotEmpty;
            print('Notification history length: ${provider.notificationHistory.length}, hasHistory: $hasHistory');
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Notifications'),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              body: !hasHistory
                  ? Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        if (hasHistory)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    provider.clearHistory();
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text('Clear All'),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: provider.notificationHistory.length,
                            itemBuilder: (context, index) {
                              final notif = provider.notificationHistory[index];
                              return _NotificationListItem(notification: notif);
                            },
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
        fullscreenDialog: false,
      ),
    );
  }

  IconData _getModuleIcon(int state) {
    switch (state) {
      case 0: return Icons.circle_outlined; // Idle
      case 1: return Icons.sensors; // Detecting
      case 2: return Icons.radio_button_checked; // Recording
      case 3: return Icons.send; // Transmitting
      default: return Icons.help_outline; // Unknown
    }
  }

  Color _getModuleColor(int state) {
    switch (state) {
      case 0: return Colors.grey; // Idle
      case 1: return Colors.blue; // Detecting
      case 2: return Colors.red; // Recording
      case 3: return Colors.green; // Transmitting
      default: return Colors.grey; // Unknown
    }
  }

  String _getModuleStateName(int state) {
    switch (state) {
      case 0: return 'Idle';
      case 1: return 'Detecting';
      case 2: return 'Recording';
      case 3: return 'Transmitting';
      default: return 'Unknown';
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final String? label;

  const _StatusIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          if (label != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1),
                ),
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryStatusIcon extends StatelessWidget {
  final int freeHeap;

  const _MemoryStatusIcon({required this.freeHeap});

  @override
  Widget build(BuildContext context) {
    final freeKB = freeHeap / 1024;
    final color = freeKB > 50 ? Colors.green : freeKB > 30 ? Colors.orange : Colors.red;
    
    return Tooltip(
      message: 'Free Heap: ${freeKB.toStringAsFixed(1)} KB',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.memory,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${freeKB.toStringAsFixed(0)}K',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  final AppNotification notification;

  const _NotificationListItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(notification.timestamp);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              notification.icon,
              size: 20,
              color: notification.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  maxLines: null,
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

