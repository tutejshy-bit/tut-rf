// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Tut RF';

  @override
  String get home => 'Главная';

  @override
  String get record => 'Запись';

  @override
  String get files => 'Файлы';

  @override
  String get settings => 'Настройки';

  @override
  String get connectionRequired => 'Требуется подключение';

  @override
  String get connectionRequiredMessage =>
      'Пожалуйста, сначала подключитесь к устройству для доступа к этой функции.';

  @override
  String get ok => 'ОК';

  @override
  String get permissionError => 'Ошибка разрешений';

  @override
  String get disconnected => 'Отключено';

  @override
  String connected(String deviceName) {
    return 'Подключено к $deviceName';
  }

  @override
  String get connecting => 'Подключение...';

  @override
  String get connectingToKnownDevice =>
      'Подключение к известному устройству...';

  @override
  String get scanningForDevice => 'Поиск устройства...';

  @override
  String get deviceNotFound =>
      'Устройство не найдено. Убедитесь, что оно включено и находится рядом.';

  @override
  String connectionError(String error) {
    return 'Ошибка подключения: $error';
  }

  @override
  String get bluetoothEnabled => 'Bluetooth включен';

  @override
  String get bluetoothDisabled => 'Bluetooth выключен';

  @override
  String get somePermissionsDenied =>
      'Некоторые разрешения отклонены. Bluetooth может работать неправильно.';

  @override
  String get allPermissionsGranted =>
      'Все разрешения предоставлены. Bluetooth готов к работе.';

  @override
  String get bluetoothScanPermissionsNotGranted =>
      'Разрешения на сканирование Bluetooth не предоставлены';

  @override
  String get scanningForDevices => 'Поиск устройств...';

  @override
  String foundSupportedDevices(int count) {
    return 'Найдено поддерживаемых устройств: $count. Нажмите для подключения.';
  }

  @override
  String get noSupportedDevicesFound =>
      'Поддерживаемые устройства не найдены. Убедитесь, что ESP32 включен и находится рядом.';

  @override
  String scanError(String error) {
    return 'Ошибка сканирования: $error';
  }

  @override
  String get scanStopped => 'Сканирование остановлено';

  @override
  String stopScanError(String error) {
    return 'Ошибка остановки сканирования: $error';
  }

  @override
  String get requiredCharacteristicsNotFound =>
      'Необходимые характеристики не найдены';

  @override
  String get requiredServiceNotFound => 'Необходимая служба не найдена';

  @override
  String get knownDeviceCleared =>
      'Известное устройство удалено. Следующее подключение будет искать устройства.';

  @override
  String get notConnected => 'Не подключено';

  @override
  String sendError(String error) {
    return 'Ошибка отправки: $error';
  }

  @override
  String get commandTimeout =>
      'Превышено время ожидания команды - попробуйте снова';

  @override
  String get fileListLoadingTimeout =>
      'Превышено время ожидания загрузки списка файлов - попробуйте снова';

  @override
  String get transmittingSignal => 'Передача сигнала...';

  @override
  String transmissionFailed(String error) {
    return 'Ошибка передачи: $error';
  }

  @override
  String get disconnect => 'Отключить';

  @override
  String get connect => 'Подключить';

  @override
  String get scanForNewDevices => 'Искать новые устройства';

  @override
  String get scanForDevices => 'Искать устройства';

  @override
  String get scanAgain => 'Искать снова';

  @override
  String foundSupportedDevicesCount(int count) {
    return 'Найдено поддерживаемых устройств: $count';
  }

  @override
  String get unknownDevice => 'Неизвестное устройство';

  @override
  String get notConnectedToDevice => 'Не подключено к устройству';

  @override
  String get connectToDeviceToManageFiles =>
      'Подключитесь к устройству для управления файлами';

  @override
  String get refresh => 'Обновить';

  @override
  String get stopLoading => 'Остановить загрузку';

  @override
  String get createDirectory => 'Создать папку';

  @override
  String get uploadFile => 'Загрузить файл';

  @override
  String get exitMultiSelect => 'Выйти из режима выбора';

  @override
  String get multiSelect => 'Множественный выбор';

  @override
  String get directoryName => 'Имя папки';

  @override
  String get enterDirectoryName => 'Введите имя папки';

  @override
  String get create => 'Создать';

  @override
  String get cancel => 'Отмена';

  @override
  String get copyFile => 'Копировать файл';

  @override
  String get newFileName => 'Новое имя файла';

  @override
  String destination(String path) {
    return 'Назначение: $path';
  }

  @override
  String get copy => 'Копировать';

  @override
  String get renameDirectory => 'Переименовать папку';

  @override
  String get renameFile => 'Переименовать файл';

  @override
  String get newDirectoryName => 'Новое имя папки';

  @override
  String get rename => 'Переименовать';

  @override
  String get deleteDirectory => 'Удалить папку';

  @override
  String get deleteFile => 'Удалить файл';

  @override
  String deleteConfirm(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?';
  }

  @override
  String get delete => 'Удалить';

  @override
  String get deleteFiles => 'Удалить файлы';

  @override
  String deleteFilesConfirm(int count) {
    return 'Вы уверены, что хотите удалить $count файлов?';
  }

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get clearSelection => 'Очистить выбор';

  @override
  String get deleteSelected => 'Удалить выбранное';

  @override
  String get moveDirectory => 'Переместить папку';

  @override
  String get moveFile => 'Переместить файл';

  @override
  String get move => 'Переместить';

  @override
  String get records => 'Записи';

  @override
  String get signals => 'Сигналы';

  @override
  String get captured => 'Захвачено';

  @override
  String get presets => 'Пресеты';

  @override
  String get temp => 'Временные';

  @override
  String get saveFileAs => 'Сохранить файл как...';

  @override
  String fileSaved(String path) {
    return 'Файл сохранен: $path';
  }

  @override
  String get fileContentCopiedToClipboard =>
      'Содержимое файла скопировано в буфер обмена';

  @override
  String fileSavedToDocuments(String path) {
    return 'Файл сохранен в Документы: $path';
  }

  @override
  String couldNotSaveFile(String error) {
    return 'Не удалось сохранить файл. Содержимое скопировано в буфер обмена. Ошибка: $error';
  }

  @override
  String downloadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get downloadFailedNoContent =>
      'Ошибка загрузки: Содержимое не получено';

  @override
  String fileCopied(String name) {
    return 'Файл скопирован: $name';
  }

  @override
  String copyFailed(String error) {
    return 'Ошибка копирования: $error';
  }

  @override
  String directoryRenamed(String name) {
    return 'Папка переименована: $name';
  }

  @override
  String fileRenamed(String name) {
    return 'Файл переименован: $name';
  }

  @override
  String renameFailed(String error) {
    return 'Ошибка переименования: $error';
  }

  @override
  String directoryDeleted(String name) {
    return 'Папка удалена: $name';
  }

  @override
  String fileDeleted(String name) {
    return 'Файл удален: $name';
  }

  @override
  String deleteFailed(String error) {
    return 'Ошибка удаления: $error';
  }

  @override
  String deletedFilesCount(int count, String extra) {
    return 'Удалено файлов: $count$extra';
  }

  @override
  String get failed => 'ошибок';

  @override
  String directoryMoved(String name) {
    return 'Папка перемещена: $name';
  }

  @override
  String fileMoved(String name) {
    return 'Файл перемещен: $name';
  }

  @override
  String moveFailed(String error) {
    return 'Ошибка перемещения: $error';
  }

  @override
  String directoryCreated(String name) {
    return 'Папка создана: $name';
  }

  @override
  String failedToCreateDirectory(String error) {
    return 'Не удалось создать папку: $error';
  }

  @override
  String uploadingFile(String fileName) {
    return 'Загрузка $fileName...';
  }

  @override
  String fileUploaded(String fileName) {
    return 'Файл загружен: $fileName';
  }

  @override
  String uploadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get selectedFileDoesNotExist => 'Выбранный файл не существует';

  @override
  String get uploadError => 'Ошибка загрузки';

  @override
  String failedToPickFile(String error) {
    return 'Не удалось выбрать файл: $error';
  }

  @override
  String get noLogsYet => 'Логов пока нет';

  @override
  String get commandsAndResponsesWillAppearHere =>
      'Команды и ответы будут отображаться здесь';

  @override
  String logsCount(int count) {
    return 'Логи ($count)';
  }

  @override
  String get clearAllLogs => 'Очистить все логи';

  @override
  String get loadingFilePreview => 'Загрузка preview файла...';

  @override
  String get previewError => 'Ошибка предпросмотра';

  @override
  String get retry => 'Повторить';

  @override
  String chars(int count) {
    return '$count символов';
  }

  @override
  String get previewTruncated =>
      'Предпросмотр обрезан. Откройте файл, чтобы увидеть полное содержимое.';

  @override
  String get clearFileCache => 'Очистить кеш файлов';

  @override
  String get requestPermissions => 'Запросить разрешения';

  @override
  String get sendCommand => 'Отправить команду';

  @override
  String get enterCommand => 'Введите команду';

  @override
  String get commandHint => 'например, SCAN, RECORD, PLAY';

  @override
  String get send => 'Отправить';

  @override
  String get scanner => 'Сканер';

  @override
  String get clearList => 'Очистить список';

  @override
  String get stop => 'Остановить';

  @override
  String get start => 'Запустить';

  @override
  String get language => 'Язык';

  @override
  String get selectLanguage => 'Выберите язык';

  @override
  String get english => 'English';

  @override
  String get russian => 'Русский';

  @override
  String get systemDefault => 'По умолчанию системы';

  @override
  String get deviceStatus => 'Статус устройства';

  @override
  String subGhzModule(int number) {
    return 'Sub-GHz Модуль $number';
  }

  @override
  String connectedToDevice(String deviceName) {
    return 'Подключено: $deviceName';
  }

  @override
  String get sdCardReady => 'SD карта готова';

  @override
  String freeHeap(String kb) {
    return 'Свободная память: $kb КБ';
  }

  @override
  String get notifications => 'Уведомления';

  @override
  String get noNotifications => 'Нет уведомлений';

  @override
  String get clearAll => 'Очистить все';

  @override
  String get justNow => 'Только что';

  @override
  String get minutesAgo => ' мин назад';

  @override
  String get hoursAgo => ' ч назад';

  @override
  String get daysAgo => ' дн назад';

  @override
  String get frequency => 'Частота';

  @override
  String get modulation => 'Манипуляция';

  @override
  String get dataRate => 'Скорость передачи данных';

  @override
  String get bandwidth => 'Полоса пропускания';

  @override
  String get deviation => 'Отклонение';

  @override
  String get rxBandwidth => 'Полоса пропускания RX';

  @override
  String get protocol => 'Протокол';

  @override
  String get preset => 'Пресет';

  @override
  String get signalName => 'Имя сигнала';

  @override
  String get settingsParseError => 'Ошибка разбора настроек';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get idle => 'Ожидание';

  @override
  String get detecting => 'Обнаружение';

  @override
  String get recording => 'Запись';

  @override
  String get jamming => 'Глушение';

  @override
  String get jammingSettings => 'Настройки глушения';

  @override
  String get transmitting => 'Передача';

  @override
  String get scanning => 'Сканирование';

  @override
  String get statusIdle => 'Бездействие';

  @override
  String get statusRecording => 'Запись';

  @override
  String get statusScanning => 'Сканирование';

  @override
  String get statusTransmitting => 'Отправка';

  @override
  String get kbps => 'кбит/с';

  @override
  String get hz => 'Гц';

  @override
  String get modulationAskOok => 'ASK/OOK (АМн-ВВ)';

  @override
  String get modulation2Fsk => '2-FSK (ЧМн-2)';

  @override
  String get modulation4Fsk => '4-FSK (ЧМн-4)';

  @override
  String get modulationGfsk => 'GFSK (ГЧМн)';

  @override
  String get modulationMsk => 'MSK (ММн)';

  @override
  String get startRecordingToCaptureSignals =>
      'Начните запись для захвата сигналов';

  @override
  String frequencySearchStoppedForModule(int number) {
    return 'Поиск частоты остановлен для Модуля $number';
  }

  @override
  String get error => 'Ошибка';

  @override
  String get deviceNotConnected => 'Устройство не подключено';

  @override
  String get moduleBusy => 'Модуль занят';

  @override
  String moduleBusyMessage(int number, String mode) {
    return 'Модуль $number сейчас в режиме \"$mode\".\\nДождитесь завершения текущей операции или переведите модуль в режим Ожидание.';
  }

  @override
  String get validationError => 'Ошибка валидации';

  @override
  String recordingStarted(int number) {
    return 'Запись начата на Модуле №$number';
  }

  @override
  String get recordingError => 'Ошибка записи';

  @override
  String recordingStartFailed(String error) {
    return 'Не удалось начать запись: $error';
  }

  @override
  String recordingStopped(int number) {
    return 'Запись остановлена на Модуле №$number';
  }

  @override
  String recordingStopFailed(String error) {
    return 'Не удалось остановить запись: $error';
  }

  @override
  String module(int number) {
    return 'Модуль $number';
  }

  @override
  String get startRecording => 'Начать запись';

  @override
  String get stopRecording => 'Остановить запись';

  @override
  String get advanced => 'Расширенные';

  @override
  String get startJamming => 'Начать глушение';

  @override
  String get stopJamming => 'Остановить глушение';

  @override
  String jammingStarted(int module) {
    return 'Глушение запущено на Модуле №$module';
  }

  @override
  String jammingStopped(int module) {
    return 'Глушение остановлено на Модуле №$module';
  }

  @override
  String get jammingError => 'Ошибка глушения';

  @override
  String jammingStartFailed(String error) {
    return 'Не удалось запустить глушение: $error';
  }

  @override
  String jammingStopFailed(String error) {
    return 'Не удалось остановить глушение: $error';
  }

  @override
  String get stopFrequencySearch => 'Остановить поиск частоты';

  @override
  String get searchForFrequency => 'Искать частоту';

  @override
  String signalsCaptured(Object count, Object number) {
    return 'Сигналов захвачено на Модуле №$number: $count';
  }

  @override
  String get recordedFiles => 'Записанные файлы';

  @override
  String get saveSignal => 'Сохранить сигнал';

  @override
  String get enterSignalName => 'Введите имя для сигнала:';

  @override
  String get deleteSignal => 'Удалить сигнал';

  @override
  String deleteSignalConfirm(String filename) {
    return 'Вы уверены, что хотите удалить \"$filename\"?\\n\\nЭто действие нельзя отменить.';
  }

  @override
  String get recordScreenHelp => 'Справка по экрану записи';

  @override
  String fileDownloadedSuccessfully(String fileName) {
    return 'Файл \"$fileName\" успешно загружен';
  }

  @override
  String get imagePreviewNotSupported =>
      'Предпросмотр изображений пока не поддерживается';

  @override
  String get viewAsText => 'Просмотр как текст';

  @override
  String get failedToParseFile => 'Не удалось разобрать файл';

  @override
  String get signalParameters => 'Параметры сигнала';

  @override
  String get signalData => 'Данные сигнала';

  @override
  String get samplesCount => 'Количество сэмплов';

  @override
  String get rawData => 'Необработанные данные:';

  @override
  String get binaryData => 'Двоичные данные:';

  @override
  String get warnings => 'Предупреждения';

  @override
  String get noContentAvailable => 'Содержимое недоступно';

  @override
  String get copyToClipboard => 'Копировать в буфер обмена';

  @override
  String get downloadFile => 'Загрузить файл';

  @override
  String get transmitSignal => 'Передать сигнал';

  @override
  String get reload => 'Перезагрузить';

  @override
  String get parsed => 'Разобрано';

  @override
  String get raw => 'Исходный';

  @override
  String get loadingFile => 'Загрузка файла...';

  @override
  String get notConnectedToDeviceFile => 'Не подключено к устройству';

  @override
  String get connectToDeviceToViewFiles =>
      'Подключитесь к устройству для просмотра файлов';

  @override
  String get transmitSignalConfirm => 'Это передаст сигнал из этого файла.';

  @override
  String get file => 'Файл';

  @override
  String get transmitWarning =>
      'Используйте только в контролируемых условиях. Проверьте местные правила.';

  @override
  String get dontShowAgain => 'Больше не показывать';

  @override
  String get resetTransmitConfirmation => 'Сбросить подтверждение передачи';

  @override
  String get transmitConfirmationReset =>
      'Диалог подтверждения передачи сброшен.';

  @override
  String get transmit => 'Передать';

  @override
  String signalTransmissionStarted(String fileName) {
    return 'Передача сигнала начата: $fileName';
  }

  @override
  String transmissionError(String error) {
    return 'Ошибка передачи: $error';
  }

  @override
  String get view => 'Просмотр';

  @override
  String get save => 'Сохранить';

  @override
  String get loadingFiles => 'Загрузка...';

  @override
  String get noRecordedFiles => 'Нет записанных файлов';

  @override
  String get noFilesFound => 'Файлы не найдены';

  @override
  String get recordSettings => 'Настройки записи';

  @override
  String get mhz => 'МГц';

  @override
  String get khz => 'кГц';

  @override
  String get kbaud => 'кБод';

  @override
  String signalSavedAs(String fileName) {
    return 'Сигнал сохранён как: $fileName';
  }

  @override
  String transmittingFile(String fileName) {
    return 'Передача сигнала из файла: $fileName';
  }

  @override
  String get recordingShort => 'Запись';

  @override
  String get freqShort => 'Част';

  @override
  String get modShort => 'Мод';

  @override
  String get rateShort => 'Скорость';

  @override
  String get bwShort => 'Полоса';

  @override
  String get clearDeviceCache => 'Очистить кеш устройств';

  @override
  String get clearDeviceCacheDescription =>
      'Удалить сохранённую информацию об устройствах';

  @override
  String filesLoadedCount(int loaded, int total) {
    return 'Загружено файлов: $loaded из $total';
  }

  @override
  String filesInDirectory(int count) {
    return 'Файлов в директории: $count';
  }

  @override
  String get noFiles => 'Нет файлов';
}
