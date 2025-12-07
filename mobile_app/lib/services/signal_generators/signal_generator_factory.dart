import '../signal_processing/signal_data.dart';
import 'base_signal_generator.dart';
import 'flipper_sub_generator.dart';

/// Фабрика для создания генераторов сигналов
/// Предоставляет единую точку входа для создания генераторов различных форматов
class SignalGeneratorFactory {
  /// Создание генератора по типу формата
  /// [format] - тип формата сигнала
  /// Возвращает соответствующий генератор
  static BaseSignalGenerator createGenerator(SignalFormat format) {
    switch (format) {
      case SignalFormat.flipperSub:
        return FlipperSubGenerator();
      case SignalFormat.tutJson:
        throw UnsupportedError('TUT JSON generator not implemented yet');
      case SignalFormat.raw:
        throw UnsupportedError('RAW generator not implemented yet');
      case SignalFormat.custom:
        throw UnsupportedError('Custom generator not implemented yet');
    }
  }
  
  /// Создание генератора по расширению файла
  /// [extension] - расширение файла (например, '.sub', '.json')
  /// Возвращает соответствующий генератор или null если формат не поддерживается
  static BaseSignalGenerator? createGeneratorByExtension(String extension) {
    final format = SignalFormat.fromExtension(extension);
    if (format == null) return null;
    
    try {
      return createGenerator(format);
    } catch (e) {
      return null;
    }
  }
  
  /// Получение списка поддерживаемых форматов
  /// Возвращает список всех доступных форматов
  static List<SignalFormat> getSupportedFormats() {
    return SignalFormat.values;
  }
  
  /// Получение списка поддерживаемых расширений
  /// Возвращает список всех поддерживаемых расширений файлов
  static List<String> getSupportedExtensions() {
    return SignalFormat.values.map((format) => format.extension).toList();
  }
  
  /// Проверка поддержки формата
  /// [extension] - расширение файла
  /// Возвращает true если формат поддерживается
  static bool isFormatSupported(String extension) {
    return SignalFormat.fromExtension(extension) != null;
  }
  
  /// Генерация файла из SignalData
  /// [signalData] - данные сигнала
  /// [format] - желаемый формат
  /// Возвращает результат генерации
  static SignalGenerationResult generateFromSignalData(
    SignalData signalData,
    SignalFormat format,
  ) {
    try {
      final generator = createGenerator(format);
      
      // Настройка генератора на основе SignalData
      if (generator is FlipperSubGenerator) {
        final flipperGenerator = FlipperSubGenerator.fromSignalData(signalData);
        return flipperGenerator.generateResult();
      }
      
      // Для других форматов - базовая настройка
      final content = generator.generate();
      return SignalGenerationResult.success(content: content);
    } catch (e) {
      return SignalGenerationResult.error(
        errors: ['Failed to generate file: $e'],
      );
    }
  }
  
  /// Автоматический выбор формата на основе содержимого
  /// [signalData] - данные сигнала
  /// Возвращает рекомендуемый формат или null если не удалось определить
  static SignalFormat? getRecommendedFormat(SignalData signalData) {
    // Если есть данные FlipperZero пресета - используем .sub формат
    if (signalData.preset != null && 
        signalData.preset!.contains('FuriHalSubGhz')) {
      return SignalFormat.flipperSub;
    }
    
    // Если есть JSON данные - используем .json формат
    if (signalData.metadata != null && signalData.metadata!.isNotEmpty) {
      return SignalFormat.tutJson;
    }
    
    // Если есть только сырые данные - используем .sub формат по умолчанию
    if (signalData.raw != null && signalData.raw!.isNotEmpty) {
      return SignalFormat.flipperSub;
    }
    
    return null;
  }
  
  /// Получение описания формата
  /// [format] - тип формата
  /// Возвращает описание формата
  static String getFormatDescription(SignalFormat format) {
    return format.description;
  }
  
  /// Получение MIME типа для формата
  /// [format] - тип формата
  /// Возвращает MIME тип
  static String getMimeType(SignalFormat format) {
    switch (format) {
      case SignalFormat.flipperSub:
        return 'text/plain';
      case SignalFormat.tutJson:
        return 'application/json';
      case SignalFormat.raw:
        return 'application/octet-stream';
      case SignalFormat.custom:
        return 'text/plain';
    }
  }
  
  /// Получение информации о генераторе
  /// [format] - тип формата
  /// Возвращает информацию о генераторе
  static Map<String, dynamic> getGeneratorInfo(SignalFormat format) {
    try {
      final generator = createGenerator(format);
      
      return {
        'format': format.id,
        'extension': format.extension,
        'description': format.description,
        'supportedExtensions': generator.getSupportedExtensions(),
        'formatDescription': generator.getFormatDescription(),
        'mimeType': getMimeType(format),
      };
    } catch (e) {
      return {
        'format': format.id,
        'extension': format.extension,
        'description': format.description,
        'error': e.toString(),
      };
    }
  }
  
  /// Получение информации о всех генераторах
  /// Возвращает список информации о всех доступных генераторах
  static List<Map<String, dynamic>> getAllGeneratorsInfo() {
    return SignalFormat.values.map(getGeneratorInfo).toList();
  }
}
