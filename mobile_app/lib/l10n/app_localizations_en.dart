// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tut RF';

  @override
  String get home => 'Home';

  @override
  String get record => 'Record';

  @override
  String get files => 'Files';

  @override
  String get settings => 'Settings';

  @override
  String get connectionRequired => 'Connection Required';

  @override
  String get connectionRequiredMessage =>
      'Please connect to a device first to access this feature.';

  @override
  String get ok => 'OK';

  @override
  String get permissionError => 'Permission Error';

  @override
  String get disconnected => 'Disconnected';

  @override
  String connected(String deviceName) {
    return 'Connected to $deviceName';
  }

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectingToKnownDevice => 'Connecting to known device...';

  @override
  String get scanningForDevice => 'Scanning for device...';

  @override
  String get deviceNotFound =>
      'Device not found. Make sure it\'s powered on and nearby.';

  @override
  String connectionError(String error) {
    return 'Connection error: $error';
  }

  @override
  String get bluetoothEnabled => 'Bluetooth enabled';

  @override
  String get bluetoothDisabled => 'Bluetooth disabled';

  @override
  String get somePermissionsDenied =>
      'Some permissions denied. Bluetooth may not work properly.';

  @override
  String get allPermissionsGranted =>
      'All permissions granted. Bluetooth ready.';

  @override
  String get bluetoothScanPermissionsNotGranted =>
      'Bluetooth scan permissions not granted';

  @override
  String get scanningForDevices => 'Scanning for devices...';

  @override
  String foundSupportedDevices(int count) {
    return 'Found $count supported device(s). Tap to connect.';
  }

  @override
  String get noSupportedDevicesFound =>
      'No supported devices found. Make sure ESP32 is powered on and nearby.';

  @override
  String scanError(String error) {
    return 'Scan error: $error';
  }

  @override
  String get scanStopped => 'Scan stopped';

  @override
  String stopScanError(String error) {
    return 'Stop scan error: $error';
  }

  @override
  String get requiredCharacteristicsNotFound =>
      'Required characteristics not found';

  @override
  String get requiredServiceNotFound => 'Required service not found';

  @override
  String get knownDeviceCleared =>
      'Known device cleared. Next connection will scan for devices.';

  @override
  String get notConnected => 'Not connected';

  @override
  String sendError(String error) {
    return 'Send error: $error';
  }

  @override
  String get commandTimeout => 'Command timeout - please try again';

  @override
  String get fileListLoadingTimeout =>
      'File list loading timeout - please try again';

  @override
  String get transmittingSignal => 'Transmitting signal...';

  @override
  String transmissionFailed(String error) {
    return 'Transmission failed: $error';
  }

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connect => 'Connect';

  @override
  String get scanForNewDevices => 'Scan for New Devices';

  @override
  String get scanForDevices => 'Scan for Devices';

  @override
  String get scanAgain => 'Scan Again';

  @override
  String foundSupportedDevicesCount(int count) {
    return 'Found $count supported device(s):';
  }

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get notConnectedToDevice => 'Not connected to device';

  @override
  String get connectToDeviceToManageFiles =>
      'Connect to a device to manage files';

  @override
  String get refresh => 'Refresh';

  @override
  String get stopLoading => 'Stop Loading';

  @override
  String get createDirectory => 'Create Directory';

  @override
  String get uploadFile => 'Upload File';

  @override
  String get exitMultiSelect => 'Exit Multi-Select';

  @override
  String get multiSelect => 'Multi-Select';

  @override
  String get directoryName => 'Directory name';

  @override
  String get enterDirectoryName => 'Enter directory name';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get copyFile => 'Copy File';

  @override
  String get newFileName => 'New file name';

  @override
  String destination(String path) {
    return 'Destination: $path';
  }

  @override
  String get copy => 'Copy';

  @override
  String get renameDirectory => 'Rename Directory';

  @override
  String get renameFile => 'Rename File';

  @override
  String get newDirectoryName => 'New directory name';

  @override
  String get rename => 'Rename';

  @override
  String get deleteDirectory => 'Delete Directory';

  @override
  String get deleteFile => 'Delete File';

  @override
  String deleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get deleteFiles => 'Delete Files';

  @override
  String deleteFilesConfirm(int count) {
    return 'Are you sure you want to delete $count files?';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clearSelection => 'Clear Selection';

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get moveDirectory => 'Move Directory';

  @override
  String get moveFile => 'Move File';

  @override
  String get move => 'Move';

  @override
  String get records => 'Records';

  @override
  String get signals => 'Signals';

  @override
  String get captured => 'Captured';

  @override
  String get presets => 'Presets';

  @override
  String get temp => 'Temp';

  @override
  String get saveFileAs => 'Save file as...';

  @override
  String fileSaved(String path) {
    return 'File saved to: $path';
  }

  @override
  String get fileContentCopiedToClipboard => 'File content copied to clipboard';

  @override
  String fileSavedToDocuments(String path) {
    return 'File saved to Documents: $path';
  }

  @override
  String couldNotSaveFile(String error) {
    return 'Could not save file. Content copied to clipboard. Error: $error';
  }

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get downloadFailedNoContent => 'Download failed: No content received';

  @override
  String fileCopied(String name) {
    return 'File copied: $name';
  }

  @override
  String copyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String directoryRenamed(String name) {
    return 'Directory renamed to: $name';
  }

  @override
  String fileRenamed(String name) {
    return 'File renamed to: $name';
  }

  @override
  String renameFailed(String error) {
    return 'Rename failed: $error';
  }

  @override
  String directoryDeleted(String name) {
    return 'Directory deleted: $name';
  }

  @override
  String fileDeleted(String name) {
    return 'File deleted: $name';
  }

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String deletedFilesCount(int count, String extra) {
    return 'Deleted $count files$extra';
  }

  @override
  String get failed => 'failed';

  @override
  String directoryMoved(String name) {
    return 'Directory moved: $name';
  }

  @override
  String fileMoved(String name) {
    return 'File moved: $name';
  }

  @override
  String moveFailed(String error) {
    return 'Move failed: $error';
  }

  @override
  String directoryCreated(String name) {
    return 'Directory created: $name';
  }

  @override
  String failedToCreateDirectory(String error) {
    return 'Failed to create directory: $error';
  }

  @override
  String uploadingFile(String fileName) {
    return 'Uploading $fileName...';
  }

  @override
  String fileUploaded(String fileName) {
    return 'File uploaded: $fileName';
  }

  @override
  String uploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get selectedFileDoesNotExist => 'Selected file does not exist';

  @override
  String get uploadError => 'Upload Error';

  @override
  String failedToPickFile(String error) {
    return 'Failed to pick file: $error';
  }

  @override
  String get noLogsYet => 'No logs yet';

  @override
  String get commandsAndResponsesWillAppearHere =>
      'Commands and responses will appear here';

  @override
  String logsCount(int count) {
    return 'Logs ($count)';
  }

  @override
  String get clearAllLogs => 'Clear all logs';

  @override
  String get loadingFilePreview => 'Loading file preview...';

  @override
  String get previewError => 'Preview Error';

  @override
  String get retry => 'Retry';

  @override
  String chars(int count) {
    return '$count chars';
  }

  @override
  String get previewTruncated =>
      'Preview truncated. Open file to see full content.';

  @override
  String get clearFileCache => 'Clear File Cache';

  @override
  String get requestPermissions => 'Request Permissions';

  @override
  String get sendCommand => 'Send Command';

  @override
  String get enterCommand => 'Enter Command';

  @override
  String get commandHint => 'e.g., SCAN, RECORD, PLAY';

  @override
  String get send => 'Send';

  @override
  String get scanner => 'Scanner';

  @override
  String get clearList => 'Clear list';

  @override
  String get stop => 'Stop';

  @override
  String get start => 'Start';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get russian => 'Russian';

  @override
  String get systemDefault => 'System Default';

  @override
  String get deviceStatus => 'Device Status';

  @override
  String subGhzModule(int number) {
    return 'Sub-GHz Module $number';
  }

  @override
  String connectedToDevice(String deviceName) {
    return 'Connected: $deviceName';
  }

  @override
  String get sdCardReady => 'SD Card ready';

  @override
  String freeHeap(String kb) {
    return 'Free Heap: $kb KB';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get clearAll => 'Clear All';

  @override
  String get justNow => 'Just now';

  @override
  String get minutesAgo => 'm ago';

  @override
  String get hoursAgo => 'h ago';

  @override
  String get daysAgo => 'd ago';

  @override
  String get frequency => 'Frequency';

  @override
  String get modulation => 'Modulation';

  @override
  String get dataRate => 'Data Rate';

  @override
  String get bandwidth => 'Bandwidth';

  @override
  String get deviation => 'Deviation';

  @override
  String get rxBandwidth => 'RX Bandwidth';

  @override
  String get protocol => 'Protocol';

  @override
  String get preset => 'Preset';

  @override
  String get signalName => 'Signal Name';

  @override
  String get settingsParseError => 'Settings Parse Error';

  @override
  String get unknown => 'Unknown';

  @override
  String get idle => 'Idle';

  @override
  String get detecting => 'Detecting';

  @override
  String get recording => 'Recording';

  @override
  String get jamming => 'Jamming';

  @override
  String get jammingSettings => 'Jamming Settings';

  @override
  String get transmitting => 'Transmitting';

  @override
  String get scanning => 'Scanning';

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusRecording => 'Recording';

  @override
  String get statusScanning => 'Scanning';

  @override
  String get statusTransmitting => 'Transmitting';

  @override
  String get kbps => 'kbps';

  @override
  String get hz => 'Hz';

  @override
  String get modulationAskOok => 'ASK/OOK';

  @override
  String get modulation2Fsk => '2-FSK';

  @override
  String get modulation4Fsk => '4-FSK';

  @override
  String get modulationGfsk => 'GFSK';

  @override
  String get modulationMsk => 'MSK';

  @override
  String get startRecordingToCaptureSignals =>
      'Start recording to capture signals';

  @override
  String frequencySearchStoppedForModule(int number) {
    return 'Frequency search stopped for Module $number';
  }

  @override
  String get error => 'Error';

  @override
  String get deviceNotConnected => 'Device not connected';

  @override
  String get moduleBusy => 'Module Busy';

  @override
  String moduleBusyMessage(int number, String mode) {
    return 'Module $number is currently in \"$mode\" mode.\\nWait for the current operation to complete or switch the module to Idle mode.';
  }

  @override
  String get validationError => 'Validation Error';

  @override
  String recordingStarted(int number) {
    return 'Recording started on module $number';
  }

  @override
  String get recordingError => 'Recording Error';

  @override
  String recordingStartFailed(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String recordingStopped(int number) {
    return 'Recording stopped on module $number';
  }

  @override
  String recordingStopFailed(String error) {
    return 'Failed to stop recording: $error';
  }

  @override
  String module(int number) {
    return 'Module $number';
  }

  @override
  String get startRecording => 'Start Recording';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get advanced => 'Advanced';

  @override
  String get startJamming => 'Start Jamming';

  @override
  String get stopJamming => 'Stop Jamming';

  @override
  String jammingStarted(int module) {
    return 'Jamming started on Module $module';
  }

  @override
  String jammingStopped(int module) {
    return 'Jamming stopped on Module $module';
  }

  @override
  String get jammingError => 'Jamming Error';

  @override
  String jammingStartFailed(String error) {
    return 'Failed to start jamming: $error';
  }

  @override
  String jammingStopFailed(String error) {
    return 'Failed to stop jamming: $error';
  }

  @override
  String get stopFrequencySearch => 'Stop frequency search';

  @override
  String get searchForFrequency => 'Search for frequency';

  @override
  String signalsCaptured(Object count, Object number) {
    return 'Module $number Signals Captured ($count)';
  }

  @override
  String get recordedFiles => 'Recorded Files';

  @override
  String get saveSignal => 'Save Signal';

  @override
  String get enterSignalName => 'Enter a name for the signal:';

  @override
  String get deleteSignal => 'Delete Signal';

  @override
  String deleteSignalConfirm(String filename) {
    return 'Are you sure you want to delete \"$filename\"?\\n\\nThis action cannot be undone.';
  }

  @override
  String get recordScreenHelp => 'Record Screen Help';

  @override
  String fileDownloadedSuccessfully(String fileName) {
    return 'File \"$fileName\" downloaded successfully';
  }

  @override
  String get imagePreviewNotSupported => 'Image preview not supported yet';

  @override
  String get viewAsText => 'View as Text';

  @override
  String get failedToParseFile => 'Failed to parse file';

  @override
  String get signalParameters => 'Signal Parameters';

  @override
  String get signalData => 'Signal Data';

  @override
  String get samplesCount => 'Samples Count';

  @override
  String get rawData => 'Raw Data:';

  @override
  String get binaryData => 'Binary Data:';

  @override
  String get warnings => 'Warnings';

  @override
  String get noContentAvailable => 'No content available';

  @override
  String get copyToClipboard => 'Copy to Clipboard';

  @override
  String get downloadFile => 'Download File';

  @override
  String get transmitSignal => 'Transmit Signal';

  @override
  String get reload => 'Reload';

  @override
  String get parsed => 'Parsed';

  @override
  String get raw => 'Raw';

  @override
  String get loadingFile => 'Loading file...';

  @override
  String get notConnectedToDeviceFile => 'Not connected to device';

  @override
  String get connectToDeviceToViewFiles => 'Connect to a device to view files';

  @override
  String get transmitSignalConfirm =>
      'This will transmit the signal from this file.';

  @override
  String get file => 'File';

  @override
  String get transmitWarning =>
      'Only use in controlled environments. Check local regulations.';

  @override
  String get dontShowAgain => 'Don\'t show this again';

  @override
  String get resetTransmitConfirmation => 'Reset Transmit Confirmation';

  @override
  String get transmitConfirmationReset =>
      'Transmit confirmation dialog has been reset.';

  @override
  String get transmit => 'Transmit';

  @override
  String signalTransmissionStarted(String fileName) {
    return 'Signal transmission started: $fileName';
  }

  @override
  String transmissionError(String error) {
    return 'Transmission error: $error';
  }

  @override
  String get view => 'View';

  @override
  String get save => 'Save';

  @override
  String get loadingFiles => 'Loading...';

  @override
  String get noRecordedFiles => 'No recorded files';

  @override
  String get noFilesFound => 'No files found';

  @override
  String get recordSettings => 'Record Settings';

  @override
  String get mhz => 'MHz';

  @override
  String get khz => 'kHz';

  @override
  String get kbaud => 'kBaud';

  @override
  String signalSavedAs(String fileName) {
    return 'Signal saved as: $fileName';
  }

  @override
  String transmittingFile(String fileName) {
    return 'Transmitting file: $fileName';
  }

  @override
  String get recordingShort => 'Recording';

  @override
  String get freqShort => 'Freq';

  @override
  String get modShort => 'Mod';

  @override
  String get rateShort => 'Rate';

  @override
  String get bwShort => 'BW';

  @override
  String get clearDeviceCache => 'Clear Device Cache';

  @override
  String get clearDeviceCacheDescription => 'Remove saved device information';

  @override
  String filesLoadedCount(int loaded, int total) {
    return 'Files loaded: $loaded of $total';
  }

  @override
  String filesInDirectory(int count) {
    return 'Files in directory: $count';
  }

  @override
  String get noFiles => 'No files';
}
