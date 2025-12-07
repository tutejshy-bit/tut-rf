import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/log_provider.dart';
import '../widgets/quick_connect_widget.dart';
import '../widgets/module_status_widget.dart';
import '../widgets/status_bar_widget.dart';
import 'files_screen.dart';
import 'debug_screen.dart';
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
    const DebugScreen(),
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
        child: Column(
          children: [
            // Status bar (под системным статус-баром, над контентом)
            const StatusBarWidget(),
            
            // Основной контент
            Expanded(
              child: _screens[_currentIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          final bleProvider = Provider.of<BleProvider>(context, listen: false);
          
          // Only allow Home screen (index 0) if not connected
          if (!bleProvider.isConnected && index != 0) {
            // Show connection required dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Connection Required'),
                content: const Text('Please connect to a device first to access this feature.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_checked),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Files',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bug_report),
            label: 'Debug',
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
              
              const SizedBox(height: 12),
              
              // Module Status Widget
              if (bleProvider.isConnected && bleProvider.cc1101Modules != null) ...[
                ModuleStatusWidget(
                  cc1101Modules: bleProvider.cc1101Modules!,
                  deviceInfo: {'freeHeap': bleProvider.freeHeap ?? 0},
                ),
                const SizedBox(height: 12),
              ],
              
              // Permissions Status (only show if there are errors)
              if (_isPermissionError(bleProvider.statusMessage)) ...[
                Card(
                  color: Colors.red,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Permission Error',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bleProvider.statusMessage,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
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
}