import '../signal_processing/signal_data.dart';
import 'base_file_parser.dart';
import 'flipper_sub_parser.dart';
import 'tut_json_parser.dart';

/// Фабрика для создания парсеров файлов сигналов
/// Предоставляет единую точку входа для создания парсеров различных форматов
class FileParserFactory {
  /// Список всех доступных парсеров
  static final List<BaseFileParser> _parsers = [
    FlipperSubParser(),
    TutJsonParser(),
  ];
  
  /// Получение парсера для содержимого файла
  /// [content] - содержимое файла
  /// Возвращает подходящий парсер или null если ни один не подходит
  static BaseFileParser? getParserForContent(String content) {
    // Сортируем парсеры по приоритету (больше = выше приоритет)
    final sortedParsers = List<BaseFileParser>.from(_parsers);
    sortedParsers.sort((a, b) => b.getPriority().compareTo(a.getPriority()));
    
    for (final parser in sortedParsers) {
      if (parser.canParse(content)) {
        return parser;
      }
    }
    
    return null;
  }
  
  /// Получение парсера по расширению файла
  /// [extension] - расширение файла (например, '.sub', '.json')
  /// Возвращает подходящий парсер или null если формат не поддерживается
  static BaseFileParser? getParserForExtension(String extension) {
    final cleanExtension = extension.startsWith('.') ? extension : '.$extension';
    
    for (final parser in _parsers) {
      if (parser.getSupportedExtensions().contains(cleanExtension)) {
        return parser;
      }
    }
    
    return null;
  }
  
  /// Получение парсера по имени файла
  /// [filename] - имя файла с расширением
  /// Возвращает подходящий парсер или null если формат не поддерживается
  static BaseFileParser? getParserForFilename(String filename) {
    final extension = filename.split('.').last;
    return getParserForExtension(extension);
  }
  
  /// Парсинг файла с автоматическим определением формата
  /// [content] - содержимое файла
  /// [filename] - имя файла (опционально, для подсказки)
  /// Возвращает результат парсинга
  static FileParseResult parseFile(String content, {String? filename}) {
    // Сначала пробуем определить по содержимому
    BaseFileParser? parser = getParserForContent(content);
    
    // Если не удалось, пробуем по имени файла
    if (parser == null && filename != null) {
      parser = getParserForFilename(filename);
    }
    
    if (parser == null) {
      return FileParseResult.error(
        errors: ['Unsupported file format. Supported formats: ${getSupportedExtensions().join(', ')}'],
        fileInfo: {
          'filename': filename,
          'size': content.length,
        },
      );
    }
    
    try {
      // Используем метод parseWithResult если доступен
      if (parser is FlipperSubParser) {
        return parser.parseWithResult(content);
      } else if (parser is TutJsonParser) {
        return parser.parseWithResult(content);
      } else {
        // Fallback к базовому методу
        final signalData = parser.parse(content);
        return FileParseResult.success(signalData: signalData);
      }
    } catch (e) {
      return FileParseResult.error(
        errors: ['Failed to parse file: $e'],
        fileInfo: {
          'filename': filename,
          'size': content.length,
          'parser': parser.runtimeType.toString(),
        },
      );
    }
  }
  
  /// Получение списка поддерживаемых расширений
  /// Возвращает список всех поддерживаемых расширений файлов
  static List<String> getSupportedExtensions() {
    final extensions = <String>{};
    for (final parser in _parsers) {
      extensions.addAll(parser.getSupportedExtensions());
    }
    return extensions.toList()..sort();
  }
  
  /// Проверка поддержки расширения
  /// [extension] - расширение файла
  /// Возвращает true если формат поддерживается
  static bool isExtensionSupported(String extension) {
    return getParserForExtension(extension) != null;
  }
  
  /// Проверка возможности парсинга содержимого
  /// [content] - содержимое файла
  /// Возвращает true если содержимое может быть распарсено
  static bool canParseContent(String content) {
    return getParserForContent(content) != null;
  }
  
  /// Получение информации о всех парсерах
  /// Возвращает список информации о всех доступных парсерах
  static List<Map<String, dynamic>> getAllParsersInfo() {
    return _parsers.map((parser) => {
      'type': parser.runtimeType.toString(),
      'extensions': parser.getSupportedExtensions(),
      'description': parser.getFormatDescription(),
      'mimeType': parser.getMimeType(),
      'priority': parser.getPriority(),
    }).toList();
  }
  
  /// Получение информации о парсере для расширения
  /// [extension] - расширение файла
  /// Возвращает информацию о парсере или null если не найден
  static Map<String, dynamic>? getParserInfo(String extension) {
    final parser = getParserForExtension(extension);
    if (parser == null) return null;
    
    return {
      'type': parser.runtimeType.toString(),
      'extensions': parser.getSupportedExtensions(),
      'description': parser.getFormatDescription(),
      'mimeType': parser.getMimeType(),
      'priority': parser.getPriority(),
    };
  }
  
  /// Быстрая проверка валидности файла
  /// [content] - содержимое файла
  /// [filename] - имя файла (опционально)
  /// Возвращает true если файл валиден
  static bool isValidFile(String content, {String? filename}) {
    final parser = getParserForContent(content) ?? 
                  (filename != null ? getParserForFilename(filename) : null);
    
    if (parser == null) return false;
    
    try {
      // Используем специализированные методы если доступны
      if (parser is FlipperSubParser) {
        return parser.isValidFile(content);
      } else if (parser is TutJsonParser) {
        return parser.isValidFile(content);
      } else {
        // Fallback к базовой проверке
        return parser.canParse(content);
      }
    } catch (e) {
      return false;
    }
  }
  
  /// Получение информации о файле без полного парсинга
  /// [content] - содержимое файла
  /// [filename] - имя файла (опционально)
  /// Возвращает информацию о файле или null если не удалось определить
  static Map<String, dynamic>? getFileInfo(String content, {String? filename}) {
    final parser = getParserForContent(content) ?? 
                  (filename != null ? getParserForFilename(filename) : null);
    
    if (parser == null) return null;
    
    try {
      // Используем специализированные методы если доступны
      if (parser is FlipperSubParser) {
        return parser.getFileInfo(content);
      } else if (parser is TutJsonParser) {
        return parser.getFileInfo(content);
      } else {
        // Fallback к базовой информации
        return {
          'parser': parser.runtimeType.toString(),
          'extensions': parser.getSupportedExtensions(),
          'description': parser.getFormatDescription(),
          'size': content.length,
        };
      }
    } catch (e) {
      return {
        'error': e.toString(),
        'size': content.length,
      };
    }
  }
  
  /// Регистрация нового парсера
  /// [parser] - новый парсер для регистрации
  static void registerParser(BaseFileParser parser) {
    // Проверяем что парсер еще не зарегистрирован
    final existingParser = _parsers.firstWhere(
      (p) => p.runtimeType == parser.runtimeType,
      orElse: () => throw ArgumentError('Parser already registered'),
    );
    
    _parsers.add(parser);
  }
  
  /// Отмена регистрации парсера
  /// [parserType] - тип парсера для удаления
  static bool unregisterParser(Type parserType) {
    final initialLength = _parsers.length;
    _parsers.removeWhere((parser) => parser.runtimeType == parserType);
    return _parsers.length < initialLength;
  }
}

