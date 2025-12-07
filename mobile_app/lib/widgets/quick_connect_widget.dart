import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';

class QuickConnectWidget extends StatelessWidget {
  const QuickConnectWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status Header
            if (bleProvider.isConnected) ...[
              Row(
                children: [
                  Icon(
                    Icons.bluetooth_connected,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Connected to ${bleProvider.savedDeviceName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    bleProvider.savedDeviceId ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => bleProvider.disconnect(),
                    icon: const Icon(Icons.bluetooth_disabled),
                    iconSize: 20,
                    tooltip: 'Disconnect',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Status Message (only show when not connected)
            if (!bleProvider.isConnected) ...[
              Text(
                bleProvider.statusMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _getStatusColor(bleProvider.statusMessage),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Device List (only show when not connected)
            if (!bleProvider.isConnected)
              _buildDeviceList(context, bleProvider),
          ],
        );
      },
    );
  }

  Widget _buildDeviceList(BuildContext context, BleProvider bleProvider) {
    if (bleProvider.isScanning) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Connecting...'),
        ),
      );
    } else if (bleProvider.savedDeviceId != null) {
      // Show saved device in simple list
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bluetooth_connected,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bleProvider.savedDeviceName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        bleProvider.savedDeviceId!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _canConnect(bleProvider) ? () => bleProvider.quickConnect() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => bleProvider.startScan(),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Scan for New Devices'),
            ),
          ),
        ],
      );
    } else {
      // No saved devices - show scan button or scan results
      List<dynamic> supportedDevices = bleProvider.supportedScanResults;
      if (supportedDevices.isNotEmpty) {
        // Show found supported devices
        return Column(
          children: [
            Text(
              'Found ${supportedDevices.length} supported device(s):',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ...supportedDevices.map((result) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.device.name.isNotEmpty ? result.device.name : 'Unknown Device',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          result.device.id.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _canConnect(bleProvider) ? () => _connectToDevice(bleProvider, result.device) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => bleProvider.startScan(),
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Again'),
              ),
            ),
          ],
        );
      } else {
        // Show scan button
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _canConnect(bleProvider) ? () => bleProvider.startScan() : null,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Scan for Devices'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _connectToDevice(BleProvider bleProvider, dynamic device) async {
    try {
      await bleProvider.connectToDevice(device);
      // Save this device for future quick connections
      await bleProvider.saveKnownDevice(device.id.toString());
    } catch (e) {
      print('Connection failed: $e');
    }
  }

  bool _canConnect(BleProvider bleProvider) {
    return !bleProvider.isScanning && 
           !bleProvider.isConnected &&
           !_isPermissionError(bleProvider.statusMessage);
  }

  bool _isPermissionError(String status) {
    return status.contains('permissions denied') || 
           status.contains('not granted') ||
           status.contains('error');
  }

  Color _getStatusColor(String status) {
    if (_isPermissionError(status)) return Colors.red;
    if (status.contains('Connected')) return Colors.green;
    if (status.contains('Scanning') || status.contains('Connecting')) return Colors.blue;
    return Colors.grey[600]!;
  }
}
