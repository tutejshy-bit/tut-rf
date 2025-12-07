import 'dart:convert';
import '../signal_processing/signal_data.dart';
import 'base_file_parser.dart';

/// Парсер для JSON файлов TUT
/// Обрабатывает файлы в формате TUT JSON для сигналов
class TutJsonParser extends BaseFileParser {
  /// Обязательные поля в JSON файле
  static const List<String> _requiredFields = ['frequency', 'raw'];
  
  /// Поддерживаемые поля
  static const List<String> _supportedFields = [
    'frequency',
    'raw',
    'binary',
    'smoothed',
    'dataRate',
    'deviation',
    'modulation',
    'pulseDuration',
    'samplesCount',
    'rxBandwidth',
    'preset',
  ];
  
  @override
  bool canParse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Проверяем обязательные поля
      for (final field in _requiredFields) {
        if (!json.containsKey(field)) {
          return false;
        }
      }
      
      // Проверяем типы данных
      if (json['frequency'] is! num) return false;
      if (json['raw'] is! String) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  SignalData parse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Проверяем обязательные поля
      for (final field in _requiredFields) {
        if (!json.containsKey(field)) {
          throw FormatException('Missing required field: $field');
        }
      }
      
      // Извлекаем данные
      final frequency = (json['frequency'] as num).toDouble();
      final raw = json['raw'] as String;
      
      if (frequency <= 0) {
        throw FormatException('Invalid frequency: $frequency');
      }
      
      if (raw.trim().isEmpty) {
        throw FormatException('Raw data is empty');
      }
      
      // Извлекаем опциональные поля
      final binary = json['binary'] as String?;
      final smoothed = json['smoothed'] as String?;
      final dataRate = json['dataRate'] != null 
          ? (json['dataRate'] as num).toDouble() 
          : null;
      final deviation = json['deviation'] != null 
          ? (json['deviation'] as num).toDouble() 
          : null;
      final modulation = json['modulation'] as String?;
      final pulseDuration = json['pulseDuration'] != null 
          ? (json['pulseDuration'] as num).toDouble() 
          : null;
      final samplesCount = json['samplesCount'] as int?;
      final rxBandwidth = json['rxBandwidth'] != null 
          ? (json['rxBandwidth'] as num).toDouble() 
          : null;
      final preset = json['preset'] as String?;
      
      // Создаем метаданные из неизвестных полей
      final metadata = <String, dynamic>{};
      for (final entry in json.entries) {
        if (!_supportedFields.contains(entry.key)) {
          metadata[entry.key] = entry.value;
        }
      }
      
      return SignalData(
        frequency: frequency,
        raw: raw,
        binary: binary,
        smoothed: smoothed,
        dataRate: dataRate,
        deviation: deviation,
        modulation: modulation,
        pulseDuration: pulseDuration,
        samplesCount: samplesCount,
        rxBandwidth: rxBandwidth,
        preset: preset,
        metadata: metadata.isNotEmpty ? metadata : null,
      );
      
    } catch (e) {
      throw FormatException('Failed to parse TUT JSON: $e');
    }
  }
  
  @override
  List<String> getSupportedExtensions() => ['.json'];
  
  @override
  String getFormatDescription() => 'TUT JSON Signal File';
  
  @override
  String getMimeType() => 'application/json';
  
  @override
  int getPriority() => 80; // Средний приоритет для JSON файлов
  
  /// Получение результата парсинга с обработкой ошибок
  FileParseResult parseWithResult(String content) {
    try {
      final signalData = parse(content);
      return FileParseResult.success(signalData: signalData);
    } catch (e) {
      return FileParseResult.error(
        errors: ['Failed to parse TUT JSON: $e'],
      );
    }
  }
  
  /// Проверка валидности JSON структуры
  bool isValidJson(String content) {
    try {
      final json = jsonDecode(content);
      return json is Map<String, dynamic>;
    } catch (e) {
      return false;
    }
  }
  
  /// Проверка валидности файла без полного парсинга
  bool isValidFile(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Проверяем обязательные поля
      for (final field in _requiredFields) {
        if (!json.containsKey(field)) {
          return false;
        }
      }
      
      // Проверяем базовые типы
      if (json['frequency'] is! num) return false;
      if (json['raw'] is! String) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Получение информации о файле без полного парсинга
  Map<String, dynamic>? getFileInfo(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      final frequency = json['frequency'] as num?;
      final hasRaw = json.containsKey('raw') && json['raw'] is String;
      final hasBinary = json.containsKey('binary');
      final hasSmoothed = json.containsKey('smoothed');
      
      return {
        'filetype': 'TUT JSON',
        'frequency': frequency?.toDouble(),
        'hasRaw': hasRaw,
        'hasBinary': hasBinary,
        'hasSmoothed': hasSmoothed,
        'fieldCount': json.keys.length,
        'isValid': frequency != null && hasRaw,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Создание JSON из SignalData
  String createJson(SignalData signalData) {
    final json = <String, dynamic>{};
    
    if (signalData.frequency != null) {
      json['frequency'] = signalData.frequency;
    }
    
    if (signalData.raw != null) {
      json['raw'] = signalData.raw;
    }
    
    if (signalData.binary != null) {
      json['binary'] = signalData.binary;
    }
    
    if (signalData.smoothed != null) {
      json['smoothed'] = signalData.smoothed;
    }
    
    if (signalData.dataRate != null) {
      json['dataRate'] = signalData.dataRate;
    }
    
    if (signalData.deviation != null) {
      json['deviation'] = signalData.deviation;
    }
    
    if (signalData.modulation != null) {
      json['modulation'] = signalData.modulation;
    }
    
    if (signalData.pulseDuration != null) {
      json['pulseDuration'] = signalData.pulseDuration;
    }
    
    if (signalData.samplesCount != null) {
      json['samplesCount'] = signalData.samplesCount;
    }
    
    if (signalData.rxBandwidth != null) {
      json['rxBandwidth'] = signalData.rxBandwidth;
    }
    
    if (signalData.preset != null) {
      json['preset'] = signalData.preset;
    }
    
    if (signalData.metadata != null) {
      json.addAll(signalData.metadata!);
    }
    
    return const JsonEncoder.withIndent('  ').convert(json);
  }
  
  /// Валидация SignalData для создания JSON
  List<String> validateSignalData(SignalData signalData) {
    final errors = <String>[];
    
    if (signalData.frequency == null || signalData.frequency! <= 0) {
      errors.add('Frequency is required and must be positive');
    }
    
    if (signalData.raw == null || signalData.raw!.trim().isEmpty) {
      errors.add('Raw data is required');
    }
    
    return errors;
  }
}

