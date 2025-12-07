import '../signal_processing/signal_data.dart';

/// Базовый класс для парсеров файлов сигналов
/// Определяет общий интерфейс для всех парсеров
abstract class BaseFileParser {
  /// Парсинг содержимого файла
  /// [content] - содержимое файла в виде строки
  /// Возвращает SignalData с распарсенными данными
  SignalData parse(String content);
  
  /// Проверка возможности парсинга файла
  /// [content] - содержимое файла для проверки
  /// Возвращает true если файл может быть распарсен этим парсером
  bool canParse(String content);
  
  /// Получение поддерживаемых расширений файлов
  /// Возвращает список расширений (например, ['.sub', '.json'])
  List<String> getSupportedExtensions();
  
  /// Получение описания формата
  /// Возвращает описание поддерживаемого формата
  String getFormatDescription();
  
  /// Получение MIME типа
  /// Возвращает MIME тип файлов этого формата
  String getMimeType();
  
  /// Получение приоритета парсера (больше = выше приоритет)
  /// Используется для выбора парсера когда несколько могут обработать файл
  int getPriority() => 50;
}

/// Результат парсинга файла
class FileParseResult {
  /// Успешность парсинга
  final bool success;
  
  /// Распарсенные данные сигнала (если успешно)
  final SignalData? signalData;
  
  /// Список ошибок (если есть)
  final List<String> errors;
  
  /// Предупреждения (не критичные проблемы)
  final List<String> warnings;
  
  /// Информация о файле
  final Map<String, dynamic>? fileInfo;
  
  FileParseResult({
    required this.success,
    this.signalData,
    this.errors = const [],
    this.warnings = const [],
    this.fileInfo,
  });
  
  /// Создание успешного результата
  factory FileParseResult.success({
    required SignalData signalData,
    List<String> warnings = const [],
    Map<String, dynamic>? fileInfo,
  }) {
    return FileParseResult(
      success: true,
      signalData: signalData,
      warnings: warnings,
      fileInfo: fileInfo,
    );
  }
  
  /// Создание результата с ошибкой
  factory FileParseResult.error({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, dynamic>? fileInfo,
  }) {
    return FileParseResult(
      success: false,
      errors: errors,
      warnings: warnings,
      fileInfo: fileInfo,
    );
  }
  
  @override
  String toString() {
    return 'FileParseResult('
        'success: $success, '
        'signalData: ${signalData != null ? 'present' : 'null'}, '
        'errors: ${errors.length}, '
        'warnings: ${warnings.length})';
  }
}

/// Информация о файле
class FileInfo {
  /// Размер файла в байтах
  final int size;
  
  /// Дата создания/изменения
  final DateTime? lastModified;
  
  /// MIME тип
  final String? mimeType;
  
  /// Кодировка (если известна)
  final String? encoding;
  
  /// Дополнительные метаданные
  final Map<String, dynamic> metadata;
  
  FileInfo({
    required this.size,
    this.lastModified,
    this.mimeType,
    this.encoding,
    this.metadata = const {},
  });
  
  @override
  String toString() {
    return 'FileInfo('
        'size: $size bytes, '
        'lastModified: $lastModified, '
        'mimeType: $mimeType)';
  }
}

