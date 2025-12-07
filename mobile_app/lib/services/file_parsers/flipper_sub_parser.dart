import '../signal_processing/signal_data.dart';
import 'base_file_parser.dart';

/// Парсер для .sub файлов FlipperZero
/// Обрабатывает файлы в формате FlipperZero SubGhz
class FlipperSubParser extends BaseFileParser {
  /// Поддерживаемые пресеты FlipperZero
  static const Map<String, Map<String, dynamic>> _presets = {
    'FuriHalSubGhzPresetOok270Async': {
      'modulation': 2,
      'rxBandwidth': 270.83,
    },
    'FuriHalSubGhzPresetOok650Async': {
      'modulation': 2,
      'rxBandwidth': 650.0,
    },
    'FuriHalSubGhzPreset2FSKDev238Async': {
      'modulation': 0,
      'deviation': 2.38,
      'dataRate': 4.8,
      'rxBandwidth': 270.83,
    },
    'FuriHalSubGhzPreset2FSKDev476Async': {
      'modulation': 0,
      'deviation': 47.6,
      'dataRate': 4.8,
      'rxBandwidth': 270.83,
    },
  };
  
  /// Поддерживаемые типы файлов
  static const List<String> _supportedFileTypes = [
    'Flipper SubGhz Key File',
    'Flipper SubGhz RAW File',
  ];
  
  @override
  bool canParse(String content) {
    try {
      final lines = content.split('\n');
      if (lines.isEmpty) return false;
      
      final firstLine = lines.first.trim();
      if (!firstLine.startsWith('Filetype:')) return false;
      
      final filetype = firstLine.split(':').length > 1 
          ? firstLine.split(':')[1].trim() 
          : '';
      
      return _supportedFileTypes.any((type) => filetype.contains(type));
    } catch (e) {
      return false;
    }
  }
  
  @override
  SignalData parse(String content) {
    try {
      final lines = content.split('\n');
      final filteredLines = lines
          .where((line) => !line.trim().startsWith('#'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      
      if (filteredLines.isEmpty) {
        throw FormatException('Empty file content');
      }
      
      // Парсинг заголовка
      final filetype = _parseFiletype(filteredLines[0]);
      if (!_supportedFileTypes.contains(filetype)) {
        throw FormatException('Unsupported file type: $filetype');
      }
      
      final version = _parseVersion(filteredLines[1]);
      if (version != 1) {
        throw FormatException('Unsupported version: $version');
      }
      
      final frequency = _parseFrequency(filteredLines[2]);
      
      // Парсинг остального содержимого
      final remainingLines = filteredLines.skip(3).toList();
      return _parseV1(remainingLines, frequency);
      
    } catch (e) {
      throw FormatException('Failed to parse .sub file: $e');
    }
  }
  
  @override
  List<String> getSupportedExtensions() => ['.sub'];
  
  @override
  String getFormatDescription() => 'FlipperZero SubGhz RAW File';
  
  @override
  String getMimeType() => 'text/plain';
  
  @override
  int getPriority() => 100; // Высокий приоритет для .sub файлов
  
  /// Парсинг версии 1 файла
  SignalData _parseV1(List<String> lines, double frequency) {
    final result = <String, dynamic>{};
    final rawData = <List<int>>[];
    String? preset;
    String? protocol;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      
      final key = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 1).trim();
      
      switch (key) {
        case 'Preset':
          preset = value;
          if (_presets.containsKey(value)) {
            final presetData = _presets[value]!;
            result.addAll(presetData);
          } else {
            throw FormatException('Unknown preset: $value');
          }
          break;
          
        case 'Protocol':
          protocol = value;
          result['protocol'] = value;
          break;
          
        case 'RAW_Data':
          try {
            final numbers = value.split(' ')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map((s) => int.tryParse(s) ?? 0)
                .toList();
            if (numbers.isNotEmpty) {
              rawData.add(numbers);
            }
          } catch (e) {
            // Игнорируем невалидные данные
            continue;
          }
          break;
          
        case 'Custom_preset_module':
        case 'Custom_preset_data':
          // Игнорируем кастомные пресеты (они сложны для парсинга)
          break;
          
        default:
          // Сохраняем неизвестные поля в метаданные
          result[key.toLowerCase()] = value;
          break;
      }
    }
    
    // Объединяем все RAW_Data в одну строку
    String? rawString;
    if (rawData.isNotEmpty) {
      rawString = rawData
          .expand((row) => row)
          .join(' ');
    }
    
    return SignalData(
      frequency: frequency,
      preset: preset,
      protocol: protocol,
      modulation: _getModulationName(result['modulation']),
      rxBandwidth: result['rxBandwidth']?.toDouble(),
      dataRate: result['dataRate']?.toDouble(),
      deviation: result['deviation']?.toDouble(),
      raw: rawString,
      rawData: rawData.isNotEmpty ? rawData : null,
      metadata: result.isNotEmpty ? result : null,
    );
  }
  
  /// Парсинг типа файла
  String _parseFiletype(String line) {
    final parts = line.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid filetype line: $line');
    }
    return parts[1].trim();
  }
  
  /// Парсинг версии
  int _parseVersion(String line) {
    final parts = line.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid version line: $line');
    }
    return int.tryParse(parts[1].trim()) ?? 1;
  }
  
  /// Парсинг частоты
  double _parseFrequency(String line) {
    final parts = line.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid frequency line: $line');
    }
    
    final frequencyStr = parts[1].trim();
    final frequency = int.tryParse(frequencyStr);
    if (frequency == null) {
      throw FormatException('Invalid frequency value: $frequencyStr');
    }
    
    return frequency.toDouble() / 1000000; // Конвертируем в MHz
  }
  
  /// Получение названия модуляции по номеру
  String _getModulationName(int? modulation) {
    if (modulation == null) return 'Unknown';
    
    switch (modulation) {
      case 0:
        return '2-FSK';
      case 1:
        return 'GFSK';
      case 2:
        return 'ASK/OOK';
      case 3:
        return 'ASK/OOK';
      case 4:
        return '4-FSK';
      case 7:
        return 'MSK';
      default:
        return 'Unknown';
    }
  }
  
  /// Получение результата парсинга с обработкой ошибок
  FileParseResult parseWithResult(String content) {
    try {
      final signalData = parse(content);
      return FileParseResult.success(signalData: signalData);
    } catch (e) {
      return FileParseResult.error(
        errors: ['Failed to parse .sub file: $e'],
      );
    }
  }
  
  /// Проверка валидности файла
  bool isValidFile(String content) {
    try {
      final lines = content.split('\n');
      if (lines.length < 3) return false;
      
      final filetype = _parseFiletype(lines[0]);
      if (!_supportedFileTypes.contains(filetype)) return false;
      
      final version = _parseVersion(lines[1]);
      if (version != 1) return false;
      
      _parseFrequency(lines[2]);
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Получение информации о файле без полного парсинга
  Map<String, dynamic>? getFileInfo(String content) {
    try {
      final lines = content.split('\n');
      if (lines.length < 3) return null;
      
      final filetype = _parseFiletype(lines[0]);
      final version = _parseVersion(lines[1]);
      final frequency = _parseFrequency(lines[2]);
      
      return {
        'filetype': filetype,
        'version': version,
        'frequency': frequency,
        'isValid': true,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
      };
    }
  }
}

