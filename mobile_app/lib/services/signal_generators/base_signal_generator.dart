import '../signal_processing/signal_data.dart';

/// Базовый класс для генераторов сигналов
/// Определяет общий интерфейс для всех генераторов
abstract class BaseSignalGenerator {
  /// Генерация содержимого файла
  /// Возвращает строку с содержимым файла
  String generate();
  
  /// Валидация данных перед генерацией
  /// Возвращает true если данные валидны
  bool validate();
  
  /// Получение списка ошибок валидации
  /// Возвращает список описаний ошибок
  List<String> getErrors();
  
  /// Получение поддерживаемых расширений файлов
  List<String> getSupportedExtensions();
  
  /// Получение описания формата
  String getFormatDescription();
}

/// Результат генерации сигнала
class SignalGenerationResult {
  /// Успешность генерации
  final bool success;
  
  /// Содержимое файла (если успешно)
  final String? content;
  
  /// Список ошибок (если есть)
  final List<String> errors;
  
  /// Тип сгенерированного файла
  final String? fileType;
  
  /// Рекомендуемое расширение файла
  final String? fileExtension;
  
  SignalGenerationResult({
    required this.success,
    this.content,
    this.errors = const [],
    this.fileType,
    this.fileExtension,
  });
  
  /// Создание успешного результата
  factory SignalGenerationResult.success({
    required String content,
    String? fileType,
    String? fileExtension,
  }) {
    return SignalGenerationResult(
      success: true,
      content: content,
      fileType: fileType,
      fileExtension: fileExtension,
    );
  }
  
  /// Создание результата с ошибкой
  factory SignalGenerationResult.error({
    required List<String> errors,
  }) {
    return SignalGenerationResult(
      success: false,
      errors: errors,
    );
  }
  
  @override
  String toString() {
    return 'SignalGenerationResult('
        'success: $success, '
        'content: ${content?.length ?? 0} chars, '
        'errors: ${errors.length})';
  }
}

/// Типы форматов сигналов
enum SignalFormat {
  flipperSub('flipper_sub', '.sub', 'FlipperZero SubGhz'),
  tutJson('tut_json', '.json', 'TUT JSON'),
  raw('raw', '.raw', 'RAW Data'),
  custom('custom', '.txt', 'Custom Format');
  
  const SignalFormat(this.id, this.extension, this.description);
  
  final String id;
  final String extension;
  final String description;
  
  /// Получение формата по ID
  static SignalFormat? fromId(String id) {
    for (final format in SignalFormat.values) {
      if (format.id == id) {
        return format;
      }
    }
    return null;
  }
  
  /// Получение формата по расширению
  static SignalFormat? fromExtension(String extension) {
    final cleanExtension = extension.startsWith('.') ? extension : '.$extension';
    
    for (final format in SignalFormat.values) {
      if (format.extension == cleanExtension) {
        return format;
      }
    }
    return null;
  }
}

