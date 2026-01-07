import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Tut RF'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Dialog title when connection is required
  ///
  /// In en, this message translates to:
  /// **'Connection Required'**
  String get connectionRequired;

  /// Dialog message when connection is required
  ///
  /// In en, this message translates to:
  /// **'Please connect to a device first to access this feature.'**
  String get connectionRequiredMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Permission error title
  ///
  /// In en, this message translates to:
  /// **'Permission Error'**
  String get permissionError;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Connection status message
  ///
  /// In en, this message translates to:
  /// **'Connected to {deviceName}'**
  String connected(String deviceName);

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connectingToKnownDevice.
  ///
  /// In en, this message translates to:
  /// **'Connecting to known device...'**
  String get connectingToKnownDevice;

  /// No description provided for @scanningForDevice.
  ///
  /// In en, this message translates to:
  /// **'Scanning for device...'**
  String get scanningForDevice;

  /// No description provided for @deviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Device not found. Make sure it\'s powered on and nearby.'**
  String get deviceNotFound;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error: {error}'**
  String connectionError(String error);

  /// No description provided for @bluetoothEnabled.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth enabled'**
  String get bluetoothEnabled;

  /// No description provided for @bluetoothDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth disabled'**
  String get bluetoothDisabled;

  /// No description provided for @somePermissionsDenied.
  ///
  /// In en, this message translates to:
  /// **'Some permissions denied. Bluetooth may not work properly.'**
  String get somePermissionsDenied;

  /// No description provided for @allPermissionsGranted.
  ///
  /// In en, this message translates to:
  /// **'All permissions granted. Bluetooth ready.'**
  String get allPermissionsGranted;

  /// No description provided for @bluetoothScanPermissionsNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth scan permissions not granted'**
  String get bluetoothScanPermissionsNotGranted;

  /// No description provided for @scanningForDevices.
  ///
  /// In en, this message translates to:
  /// **'Scanning for devices...'**
  String get scanningForDevices;

  /// No description provided for @foundSupportedDevices.
  ///
  /// In en, this message translates to:
  /// **'Found {count} supported device(s). Tap to connect.'**
  String foundSupportedDevices(int count);

  /// No description provided for @noSupportedDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No supported devices found. Make sure ESP32 is powered on and nearby.'**
  String get noSupportedDevicesFound;

  /// No description provided for @scanError.
  ///
  /// In en, this message translates to:
  /// **'Scan error: {error}'**
  String scanError(String error);

  /// No description provided for @scanStopped.
  ///
  /// In en, this message translates to:
  /// **'Scan stopped'**
  String get scanStopped;

  /// No description provided for @stopScanError.
  ///
  /// In en, this message translates to:
  /// **'Stop scan error: {error}'**
  String stopScanError(String error);

  /// No description provided for @requiredCharacteristicsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Required characteristics not found'**
  String get requiredCharacteristicsNotFound;

  /// No description provided for @requiredServiceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Required service not found'**
  String get requiredServiceNotFound;

  /// No description provided for @knownDeviceCleared.
  ///
  /// In en, this message translates to:
  /// **'Known device cleared. Next connection will scan for devices.'**
  String get knownDeviceCleared;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @sendError.
  ///
  /// In en, this message translates to:
  /// **'Send error: {error}'**
  String sendError(String error);

  /// No description provided for @commandTimeout.
  ///
  /// In en, this message translates to:
  /// **'Command timeout - please try again'**
  String get commandTimeout;

  /// No description provided for @fileListLoadingTimeout.
  ///
  /// In en, this message translates to:
  /// **'File list loading timeout - please try again'**
  String get fileListLoadingTimeout;

  /// No description provided for @transmittingSignal.
  ///
  /// In en, this message translates to:
  /// **'Transmitting signal...'**
  String get transmittingSignal;

  /// No description provided for @transmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transmission failed: {error}'**
  String transmissionFailed(String error);

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @scanForNewDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan for New Devices'**
  String get scanForNewDevices;

  /// No description provided for @scanForDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan for Devices'**
  String get scanForDevices;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get scanAgain;

  /// No description provided for @foundSupportedDevicesCount.
  ///
  /// In en, this message translates to:
  /// **'Found {count} supported device(s):'**
  String foundSupportedDevicesCount(int count);

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @notConnectedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Not connected to device'**
  String get notConnectedToDevice;

  /// No description provided for @connectToDeviceToManageFiles.
  ///
  /// In en, this message translates to:
  /// **'Connect to a device to manage files'**
  String get connectToDeviceToManageFiles;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @stopLoading.
  ///
  /// In en, this message translates to:
  /// **'Stop Loading'**
  String get stopLoading;

  /// No description provided for @createDirectory.
  ///
  /// In en, this message translates to:
  /// **'Create Directory'**
  String get createDirectory;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFile;

  /// No description provided for @exitMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Exit Multi-Select'**
  String get exitMultiSelect;

  /// No description provided for @multiSelect.
  ///
  /// In en, this message translates to:
  /// **'Multi-Select'**
  String get multiSelect;

  /// No description provided for @directoryName.
  ///
  /// In en, this message translates to:
  /// **'Directory name'**
  String get directoryName;

  /// No description provided for @enterDirectoryName.
  ///
  /// In en, this message translates to:
  /// **'Enter directory name'**
  String get enterDirectoryName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @copyFile.
  ///
  /// In en, this message translates to:
  /// **'Copy File'**
  String get copyFile;

  /// No description provided for @newFileName.
  ///
  /// In en, this message translates to:
  /// **'New file name'**
  String get newFileName;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination: {path}'**
  String destination(String path);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @renameDirectory.
  ///
  /// In en, this message translates to:
  /// **'Rename Directory'**
  String get renameDirectory;

  /// No description provided for @renameFile.
  ///
  /// In en, this message translates to:
  /// **'Rename File'**
  String get renameFile;

  /// No description provided for @newDirectoryName.
  ///
  /// In en, this message translates to:
  /// **'New directory name'**
  String get newDirectoryName;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @deleteDirectory.
  ///
  /// In en, this message translates to:
  /// **'Delete Directory'**
  String get deleteDirectory;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteConfirm(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete Files'**
  String get deleteFiles;

  /// No description provided for @deleteFilesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} files?'**
  String deleteFilesConfirm(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get clearSelection;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelected;

  /// No description provided for @moveDirectory.
  ///
  /// In en, this message translates to:
  /// **'Move Directory'**
  String get moveDirectory;

  /// No description provided for @moveFile.
  ///
  /// In en, this message translates to:
  /// **'Move File'**
  String get moveFile;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// No description provided for @signals.
  ///
  /// In en, this message translates to:
  /// **'Signals'**
  String get signals;

  /// No description provided for @captured.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get captured;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get temp;

  /// No description provided for @saveFileAs.
  ///
  /// In en, this message translates to:
  /// **'Save file as...'**
  String get saveFileAs;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved to: {path}'**
  String fileSaved(String path);

  /// No description provided for @fileContentCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'File content copied to clipboard'**
  String get fileContentCopiedToClipboard;

  /// No description provided for @fileSavedToDocuments.
  ///
  /// In en, this message translates to:
  /// **'File saved to Documents: {path}'**
  String fileSavedToDocuments(String path);

  /// No description provided for @couldNotSaveFile.
  ///
  /// In en, this message translates to:
  /// **'Could not save file. Content copied to clipboard. Error: {error}'**
  String couldNotSaveFile(String error);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @downloadFailedNoContent.
  ///
  /// In en, this message translates to:
  /// **'Download failed: No content received'**
  String get downloadFailedNoContent;

  /// No description provided for @fileCopied.
  ///
  /// In en, this message translates to:
  /// **'File copied: {name}'**
  String fileCopied(String name);

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String copyFailed(String error);

  /// No description provided for @directoryRenamed.
  ///
  /// In en, this message translates to:
  /// **'Directory renamed to: {name}'**
  String directoryRenamed(String name);

  /// No description provided for @fileRenamed.
  ///
  /// In en, this message translates to:
  /// **'File renamed to: {name}'**
  String fileRenamed(String name);

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Rename failed: {error}'**
  String renameFailed(String error);

  /// No description provided for @directoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Directory deleted: {name}'**
  String directoryDeleted(String name);

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted: {name}'**
  String fileDeleted(String name);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// No description provided for @deletedFilesCount.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} files{extra}'**
  String deletedFilesCount(int count, String extra);

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get failed;

  /// No description provided for @directoryMoved.
  ///
  /// In en, this message translates to:
  /// **'Directory moved: {name}'**
  String directoryMoved(String name);

  /// No description provided for @fileMoved.
  ///
  /// In en, this message translates to:
  /// **'File moved: {name}'**
  String fileMoved(String name);

  /// No description provided for @moveFailed.
  ///
  /// In en, this message translates to:
  /// **'Move failed: {error}'**
  String moveFailed(String error);

  /// No description provided for @directoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Directory created: {name}'**
  String directoryCreated(String name);

  /// No description provided for @failedToCreateDirectory.
  ///
  /// In en, this message translates to:
  /// **'Failed to create directory: {error}'**
  String failedToCreateDirectory(String error);

  /// No description provided for @uploadingFile.
  ///
  /// In en, this message translates to:
  /// **'Uploading {fileName}...'**
  String uploadingFile(String fileName);

  /// No description provided for @fileUploaded.
  ///
  /// In en, this message translates to:
  /// **'File uploaded: {fileName}'**
  String fileUploaded(String fileName);

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(String error);

  /// No description provided for @selectedFileDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Selected file does not exist'**
  String get selectedFileDoesNotExist;

  /// No description provided for @uploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload Error'**
  String get uploadError;

  /// No description provided for @failedToPickFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick file: {error}'**
  String failedToPickFile(String error);

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get noLogsYet;

  /// No description provided for @commandsAndResponsesWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Commands and responses will appear here'**
  String get commandsAndResponsesWillAppearHere;

  /// No description provided for @logsCount.
  ///
  /// In en, this message translates to:
  /// **'Logs ({count})'**
  String logsCount(int count);

  /// No description provided for @clearAllLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs'**
  String get clearAllLogs;

  /// No description provided for @loadingFilePreview.
  ///
  /// In en, this message translates to:
  /// **'Loading file preview...'**
  String get loadingFilePreview;

  /// No description provided for @previewError.
  ///
  /// In en, this message translates to:
  /// **'Preview Error'**
  String get previewError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @chars.
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String chars(int count);

  /// No description provided for @previewTruncated.
  ///
  /// In en, this message translates to:
  /// **'Preview truncated. Open file to see full content.'**
  String get previewTruncated;

  /// No description provided for @clearFileCache.
  ///
  /// In en, this message translates to:
  /// **'Clear File Cache'**
  String get clearFileCache;

  /// No description provided for @requestPermissions.
  ///
  /// In en, this message translates to:
  /// **'Request Permissions'**
  String get requestPermissions;

  /// No description provided for @sendCommand.
  ///
  /// In en, this message translates to:
  /// **'Send Command'**
  String get sendCommand;

  /// No description provided for @enterCommand.
  ///
  /// In en, this message translates to:
  /// **'Enter Command'**
  String get enterCommand;

  /// No description provided for @commandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., SCAN, RECORD, PLAY'**
  String get commandHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @scanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get scanner;

  /// No description provided for @clearList.
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get clearList;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @deviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Device Status'**
  String get deviceStatus;

  /// No description provided for @subGhzModule.
  ///
  /// In en, this message translates to:
  /// **'Sub-GHz Module {number}'**
  String subGhzModule(int number);

  /// No description provided for @connectedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Connected: {deviceName}'**
  String connectedToDevice(String deviceName);

  /// No description provided for @sdCardReady.
  ///
  /// In en, this message translates to:
  /// **'SD Card ready'**
  String get sdCardReady;

  /// No description provided for @freeHeap.
  ///
  /// In en, this message translates to:
  /// **'Free Heap: {kb} KB'**
  String freeHeap(String kb);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'m ago'**
  String get minutesAgo;

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'h ago'**
  String get hoursAgo;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'d ago'**
  String get daysAgo;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @modulation.
  ///
  /// In en, this message translates to:
  /// **'Modulation'**
  String get modulation;

  /// No description provided for @dataRate.
  ///
  /// In en, this message translates to:
  /// **'Data Rate'**
  String get dataRate;

  /// No description provided for @bandwidth.
  ///
  /// In en, this message translates to:
  /// **'Bandwidth'**
  String get bandwidth;

  /// No description provided for @deviation.
  ///
  /// In en, this message translates to:
  /// **'Deviation'**
  String get deviation;

  /// No description provided for @rxBandwidth.
  ///
  /// In en, this message translates to:
  /// **'RX Bandwidth'**
  String get rxBandwidth;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @preset.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get preset;

  /// No description provided for @signalName.
  ///
  /// In en, this message translates to:
  /// **'Signal Name'**
  String get signalName;

  /// No description provided for @settingsParseError.
  ///
  /// In en, this message translates to:
  /// **'Settings Parse Error'**
  String get settingsParseError;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @detecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting'**
  String get detecting;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// No description provided for @jamming.
  ///
  /// In en, this message translates to:
  /// **'Jamming'**
  String get jamming;

  /// No description provided for @jammingSettings.
  ///
  /// In en, this message translates to:
  /// **'Jamming Settings'**
  String get jammingSettings;

  /// No description provided for @transmitting.
  ///
  /// In en, this message translates to:
  /// **'Transmitting'**
  String get transmitting;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanning;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @statusRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get statusRecording;

  /// No description provided for @statusScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get statusScanning;

  /// No description provided for @statusTransmitting.
  ///
  /// In en, this message translates to:
  /// **'Transmitting'**
  String get statusTransmitting;

  /// No description provided for @kbps.
  ///
  /// In en, this message translates to:
  /// **'kbps'**
  String get kbps;

  /// No description provided for @hz.
  ///
  /// In en, this message translates to:
  /// **'Hz'**
  String get hz;

  /// No description provided for @modulationAskOok.
  ///
  /// In en, this message translates to:
  /// **'ASK/OOK'**
  String get modulationAskOok;

  /// No description provided for @modulation2Fsk.
  ///
  /// In en, this message translates to:
  /// **'2-FSK'**
  String get modulation2Fsk;

  /// No description provided for @modulation4Fsk.
  ///
  /// In en, this message translates to:
  /// **'4-FSK'**
  String get modulation4Fsk;

  /// No description provided for @modulationGfsk.
  ///
  /// In en, this message translates to:
  /// **'GFSK'**
  String get modulationGfsk;

  /// No description provided for @modulationMsk.
  ///
  /// In en, this message translates to:
  /// **'MSK'**
  String get modulationMsk;

  /// No description provided for @startRecordingToCaptureSignals.
  ///
  /// In en, this message translates to:
  /// **'Start recording to capture signals'**
  String get startRecordingToCaptureSignals;

  /// No description provided for @frequencySearchStoppedForModule.
  ///
  /// In en, this message translates to:
  /// **'Frequency search stopped for Module {number}'**
  String frequencySearchStoppedForModule(int number);

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @deviceNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Device not connected'**
  String get deviceNotConnected;

  /// No description provided for @moduleBusy.
  ///
  /// In en, this message translates to:
  /// **'Module Busy'**
  String get moduleBusy;

  /// No description provided for @moduleBusyMessage.
  ///
  /// In en, this message translates to:
  /// **'Module {number} is currently in \"{mode}\" mode.\\nWait for the current operation to complete or switch the module to Idle mode.'**
  String moduleBusyMessage(int number, String mode);

  /// No description provided for @validationError.
  ///
  /// In en, this message translates to:
  /// **'Validation Error'**
  String get validationError;

  /// No description provided for @recordingStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording started on module {number}'**
  String recordingStarted(int number);

  /// No description provided for @recordingError.
  ///
  /// In en, this message translates to:
  /// **'Recording Error'**
  String get recordingError;

  /// No description provided for @recordingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String recordingStartFailed(String error);

  /// No description provided for @recordingStopped.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped on module {number}'**
  String recordingStopped(int number);

  /// No description provided for @recordingStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop recording: {error}'**
  String recordingStopFailed(String error);

  /// No description provided for @module.
  ///
  /// In en, this message translates to:
  /// **'Module {number}'**
  String module(int number);

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @startJamming.
  ///
  /// In en, this message translates to:
  /// **'Start Jamming'**
  String get startJamming;

  /// No description provided for @stopJamming.
  ///
  /// In en, this message translates to:
  /// **'Stop Jamming'**
  String get stopJamming;

  /// No description provided for @jammingStarted.
  ///
  /// In en, this message translates to:
  /// **'Jamming started on Module {module}'**
  String jammingStarted(int module);

  /// No description provided for @jammingStopped.
  ///
  /// In en, this message translates to:
  /// **'Jamming stopped on Module {module}'**
  String jammingStopped(int module);

  /// No description provided for @jammingError.
  ///
  /// In en, this message translates to:
  /// **'Jamming Error'**
  String get jammingError;

  /// No description provided for @jammingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start jamming: {error}'**
  String jammingStartFailed(String error);

  /// No description provided for @jammingStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop jamming: {error}'**
  String jammingStopFailed(String error);

  /// No description provided for @stopFrequencySearch.
  ///
  /// In en, this message translates to:
  /// **'Stop frequency search'**
  String get stopFrequencySearch;

  /// No description provided for @searchForFrequency.
  ///
  /// In en, this message translates to:
  /// **'Search for frequency'**
  String get searchForFrequency;

  /// No description provided for @signalsCaptured.
  ///
  /// In en, this message translates to:
  /// **'Module {number} Signals Captured ({count})'**
  String signalsCaptured(Object count, Object number);

  /// No description provided for @recordedFiles.
  ///
  /// In en, this message translates to:
  /// **'Recorded Files'**
  String get recordedFiles;

  /// No description provided for @saveSignal.
  ///
  /// In en, this message translates to:
  /// **'Save Signal'**
  String get saveSignal;

  /// No description provided for @enterSignalName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the signal:'**
  String get enterSignalName;

  /// No description provided for @deleteSignal.
  ///
  /// In en, this message translates to:
  /// **'Delete Signal'**
  String get deleteSignal;

  /// No description provided for @deleteSignalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{filename}\"?\\n\\nThis action cannot be undone.'**
  String deleteSignalConfirm(String filename);

  /// No description provided for @recordScreenHelp.
  ///
  /// In en, this message translates to:
  /// **'Record Screen Help'**
  String get recordScreenHelp;

  /// No description provided for @fileDownloadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'File \"{fileName}\" downloaded successfully'**
  String fileDownloadedSuccessfully(String fileName);

  /// No description provided for @imagePreviewNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Image preview not supported yet'**
  String get imagePreviewNotSupported;

  /// No description provided for @viewAsText.
  ///
  /// In en, this message translates to:
  /// **'View as Text'**
  String get viewAsText;

  /// No description provided for @failedToParseFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse file'**
  String get failedToParseFile;

  /// No description provided for @signalParameters.
  ///
  /// In en, this message translates to:
  /// **'Signal Parameters'**
  String get signalParameters;

  /// No description provided for @signalData.
  ///
  /// In en, this message translates to:
  /// **'Signal Data'**
  String get signalData;

  /// No description provided for @samplesCount.
  ///
  /// In en, this message translates to:
  /// **'Samples Count'**
  String get samplesCount;

  /// No description provided for @rawData.
  ///
  /// In en, this message translates to:
  /// **'Raw Data:'**
  String get rawData;

  /// No description provided for @binaryData.
  ///
  /// In en, this message translates to:
  /// **'Binary Data:'**
  String get binaryData;

  /// No description provided for @warnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warnings;

  /// No description provided for @noContentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get noContentAvailable;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// No description provided for @downloadFile.
  ///
  /// In en, this message translates to:
  /// **'Download File'**
  String get downloadFile;

  /// No description provided for @transmitSignal.
  ///
  /// In en, this message translates to:
  /// **'Transmit Signal'**
  String get transmitSignal;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @parsed.
  ///
  /// In en, this message translates to:
  /// **'Parsed'**
  String get parsed;

  /// No description provided for @raw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get raw;

  /// No description provided for @loadingFile.
  ///
  /// In en, this message translates to:
  /// **'Loading file...'**
  String get loadingFile;

  /// No description provided for @notConnectedToDeviceFile.
  ///
  /// In en, this message translates to:
  /// **'Not connected to device'**
  String get notConnectedToDeviceFile;

  /// No description provided for @connectToDeviceToViewFiles.
  ///
  /// In en, this message translates to:
  /// **'Connect to a device to view files'**
  String get connectToDeviceToViewFiles;

  /// No description provided for @transmitSignalConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will transmit the signal from this file.'**
  String get transmitSignalConfirm;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @transmitWarning.
  ///
  /// In en, this message translates to:
  /// **'Only use in controlled environments. Check local regulations.'**
  String get transmitWarning;

  /// No description provided for @dontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this again'**
  String get dontShowAgain;

  /// No description provided for @resetTransmitConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Reset Transmit Confirmation'**
  String get resetTransmitConfirmation;

  /// No description provided for @transmitConfirmationReset.
  ///
  /// In en, this message translates to:
  /// **'Transmit confirmation dialog has been reset.'**
  String get transmitConfirmationReset;

  /// No description provided for @transmit.
  ///
  /// In en, this message translates to:
  /// **'Transmit'**
  String get transmit;

  /// No description provided for @signalTransmissionStarted.
  ///
  /// In en, this message translates to:
  /// **'Signal transmission started: {fileName}'**
  String signalTransmissionStarted(String fileName);

  /// No description provided for @transmissionError.
  ///
  /// In en, this message translates to:
  /// **'Transmission error: {error}'**
  String transmissionError(String error);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @loadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingFiles;

  /// No description provided for @noRecordedFiles.
  ///
  /// In en, this message translates to:
  /// **'No recorded files'**
  String get noRecordedFiles;

  /// No description provided for @noFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get noFilesFound;

  /// No description provided for @recordSettings.
  ///
  /// In en, this message translates to:
  /// **'Record Settings'**
  String get recordSettings;

  /// No description provided for @mhz.
  ///
  /// In en, this message translates to:
  /// **'MHz'**
  String get mhz;

  /// No description provided for @khz.
  ///
  /// In en, this message translates to:
  /// **'kHz'**
  String get khz;

  /// No description provided for @kbaud.
  ///
  /// In en, this message translates to:
  /// **'kBaud'**
  String get kbaud;

  /// No description provided for @signalSavedAs.
  ///
  /// In en, this message translates to:
  /// **'Signal saved as: {fileName}'**
  String signalSavedAs(String fileName);

  /// No description provided for @transmittingFile.
  ///
  /// In en, this message translates to:
  /// **'Transmitting file: {fileName}'**
  String transmittingFile(String fileName);

  /// No description provided for @recordingShort.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingShort;

  /// No description provided for @freqShort.
  ///
  /// In en, this message translates to:
  /// **'Freq'**
  String get freqShort;

  /// No description provided for @modShort.
  ///
  /// In en, this message translates to:
  /// **'Mod'**
  String get modShort;

  /// No description provided for @rateShort.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateShort;

  /// No description provided for @bwShort.
  ///
  /// In en, this message translates to:
  /// **'BW'**
  String get bwShort;

  /// No description provided for @clearDeviceCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Device Cache'**
  String get clearDeviceCache;

  /// No description provided for @clearDeviceCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove saved device information'**
  String get clearDeviceCacheDescription;

  /// No description provided for @filesLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'Files loaded: {loaded} of {total}'**
  String filesLoadedCount(int loaded, int total);

  /// No description provided for @filesInDirectory.
  ///
  /// In en, this message translates to:
  /// **'Files in directory: {count}'**
  String filesInDirectory(int count);

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get noFiles;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
