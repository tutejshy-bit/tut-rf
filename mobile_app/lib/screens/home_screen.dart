import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/log_provider.dart';
import '../widgets/quick_connect_widget.dart';
import '../widgets/module_status_widget.dart';
import '../widgets/status_bar_widget.dart';
import '../theme/app_colors.dart';
import 'files_screen.dart';
import 'settings_screen.dart';
import 'record_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const RecordScreen(),
    const FilesScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Устанавливаем callback для логирования
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      final logProvider = Provider.of<LogProvider>(context, listen: false);
      
      // Listen for connection state changes
      bleProvider.addListener(_onConnectionStateChanged);
      
      bleProvider.setLogCallback((level, message, {details}) {
        switch (level) {
          case 'command':
            logProvider.addCommandLog(message);
            break;
          case 'response':
            logProvider.addResponseLog(message);
            break;
          case 'info':
            logProvider.addInfoLog(message);
            break;
          case 'error':
            logProvider.addErrorLog(message);
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    bleProvider.removeListener(_onConnectionStateChanged);
    super.dispose();
  }

  void _onConnectionStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Основной контент с отступом сверху для тулбара
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: _screens[_currentIndex],
            ),
            
            // Status bar overlay (поверх контента)
            const StatusBarWidget(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          final bleProvider = Provider.of<BleProvider>(context, listen: false);
          
          // Allow Home (index 0) and Settings (index 3) without connection
          // Block Record (index 1) and Files (index 2) if not connected
          if (!bleProvider.isConnected && index != 0 && index != 3) {
            // Show connection required dialog
            final l10n = AppLocalizations.of(context)!;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  l10n.connectionRequired,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                content: Text(
                  l10n.connectionRequiredMessage,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            );
            return;
          }
          
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.radio_button_checked),
            label: AppLocalizations.of(context)!.record,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder),
            label: AppLocalizations.of(context)!.files,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick Connect Widget
              const QuickConnectWidget(),
              
              // Permissions Status (only show if there are errors)
              if (_isPermissionError(bleProvider.statusMessage)) ...[
                Card(
                  color: AppColors.error,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error,
                              color: AppColors.primaryText,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.permissionError,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getLocalizedStatusMessage(context, bleProvider.statusMessage),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _isPermissionError(String status) {
    return status.contains('permission') || 
           status.contains('Permission') ||
           status.contains('denied') ||
           status.contains('error');
  }

  String _getLocalizedStatusMessage(BuildContext context, String statusKey) {
    final l10n = AppLocalizations.of(context)!;
    
    // Handle keys with parameters (format: "key:value")
    if (statusKey.contains(':')) {
      final parts = statusKey.split(':');
      final key = parts[0];
      final value = parts.length > 1 ? parts[1] : '';
      
      switch (key) {
        case 'foundSupportedDevices':
          final count = int.tryParse(value) ?? 0;
          return l10n.foundSupportedDevices(count);
        default:
          return statusKey; // Return as-is if not a known key
      }
    }
    
    // Handle simple keys without parameters
    switch (statusKey) {
      case 'connecting':
        return l10n.connecting;
      case 'connectingToKnownDevice':
        return l10n.connectingToKnownDevice;
      case 'disconnected':
        return l10n.disconnected;
      case 'scanningForDevices':
        return l10n.scanningForDevices;
      case 'transmittingSignal':
        return l10n.transmittingSignal;
      default:
        // Если содержит "Transmitting signal...", тоже локализуем
        if (statusKey.contains('Transmitting signal')) {
          return l10n.transmittingSignal;
        }
        return statusKey; // Return as-is if not a known key
    }
  }
}