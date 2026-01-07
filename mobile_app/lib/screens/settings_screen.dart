import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/transmit_file_dialog.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Компактный заголовок
          Container(
            height: 48,
            color: AppColors.secondaryBackground,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.settings, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.settings,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Контент
          Expanded(
            child: Consumer<BleProvider>(
              builder: (context, bleProvider, child) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Settings Controls
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 0),
                              
                              // Language Selection
                              Consumer<LocaleProvider>(
                                builder: (context, localeProvider, child) {
                                  final l10n = AppLocalizations.of(context)!;
                                  return Card(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: ListTile(
                                      leading: const Icon(Icons.language),
                                      title: Text(l10n.language),
                                      subtitle: Text(_getLanguageDisplayName(localeProvider.locale.languageCode, l10n)),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _showLanguageDialog(context, localeProvider, l10n),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Settings Controls
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => bleProvider.clearFileCache(),
                                    icon: const Icon(Icons.folder_delete),
                                    label: Text(AppLocalizations.of(context)!.clearFileCache),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.recording,
                                      foregroundColor: AppColors.primaryBackground,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => bleProvider.requestPermissions(),
                                    icon: const Icon(Icons.security),
                                    label: Text(AppLocalizations.of(context)!.requestPermissions),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showClearDeviceCacheDialog(context, bleProvider),
                                    icon: const Icon(Icons.bluetooth_disabled),
                                    label: Text(AppLocalizations.of(context)!.clearDeviceCache),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.info,
                                      foregroundColor: AppColors.primaryBackground,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _resetTransmitConfirmation(context),
                                    icon: const Icon(Icons.refresh),
                                    label: Text(AppLocalizations.of(context)!.resetTransmitConfirmation),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.info,
                                      foregroundColor: AppColors.primaryBackground,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  String _getLanguageDisplayName(String languageCode, AppLocalizations l10n) {
    switch (languageCode) {
      case 'en':
        return l10n.english;
      case 'ru':
        return l10n.russian;
      default:
        return l10n.systemDefault;
    }
  }
  
  void _showLanguageDialog(BuildContext context, LocaleProvider localeProvider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final currentLocale = localeProvider.locale;
        return AlertDialog(
          title: Text(
            l10n.selectLanguage,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(
                  l10n.english,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                value: 'en',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    localeProvider.setLocale(Locale(value));
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  l10n.russian,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                value: 'ru',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    localeProvider.setLocale(Locale(value));
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }
  
  void _showClearDeviceCacheDialog(BuildContext context, BleProvider bleProvider) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.clearDeviceCache,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: Text(
            l10n.clearDeviceCacheDescription,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                await bleProvider.clearDeviceCache();
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.clearDeviceCache)),
                );
              },
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }
  
  void _resetTransmitConfirmation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await TransmitFileDialog.resetDontShowAgain();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.transmitConfirmationReset),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}


