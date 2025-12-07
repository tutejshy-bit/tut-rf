# Перенос основной логики из VueJS в Flutter

## Обзор

Этот документ описывает перенос критически важной логики из VueJS приложения, включая генераторы файлов, парсеры, значения CC1101 и калькуляторы.

## Компоненты для переноса

### 1. Генератор .sub файлов для FlipperZero
**Файл:** `utils/generator/fz-sub.js`
**Назначение:** Генерация .sub файлов для FlipperZero с поддержкой различных форматов

### 2. Парсер файлов
**Файл:** `utils/file-parsers/parser.js`
**Назначение:** Парсинг различных форматов файлов сигналов

### 3. Значения CC1101
**Файл:** `lib/values.js`
**Назначение:** Предопределенные значения для настройки модуля CC1101

### 4. Калькулятор CC1101
**Файл:** `lib/cc1101-calculator.js`
**Назначение:** Расчеты и парсинг статуса CC1101

## Структура переноса

### lib/services/
```
lib/services/
├── signal_generators/
│   ├── base_signal_generator.dart
│   ├── flipper_sub_generator.dart
│   └── signal_generator_factory.dart
├── file_parsers/
│   ├── base_file_parser.dart
│   ├── flipper_sub_parser.dart
│   ├── tut_json_parser.dart
│   └── file_parser_factory.dart
├── cc1101/
│   ├── cc1101_values.dart
│   ├── cc1101_calculator.dart
│   └── cc1101_config.dart
└── signal_processing/
    ├── signal_data.dart
    └── signal_analyzer.dart
```

## 1. Генератор .sub файлов

### Базовый генератор
```dart
// lib/services/signal_generators/base_signal_generator.dart
abstract class BaseSignalGenerator {
  String generate();
  bool validate();
  List<String> getErrors();
}

class SignalGenerationResult {
  final bool success;
  final String? content;
  final List<String> errors;
  
  SignalGenerationResult({
    required this.success,
    this.content,
    this.errors = const [],
  });
}
```

### Генератор FlipperZero .sub файлов
```dart
// lib/services/signal_generators/flipper_sub_generator.dart
class FlipperSubGenerator extends BaseSignalGenerator {
  static const List<String> _supportedPresets = [
    'FuriHalSubGhzPresetOok270Async',
    'FuriHalSubGhzPresetOok650Async',
    'FuriHalSubGhzPreset2FSKDev238Async',
    'FuriHalSubGhzPreset2FSKDev476Async',
  ];
  
  static const Map<String, int> _modulationTypes = {
    '2-FSK': 0,
    'GFSK': 1,
    'ASK/OOK': 3,
    '4-FSK': 4,
    'MSK': 7,
  };
  
  static const Map<String, String> _configurationRegisters = {
    'MDMCFG4': '10',
    'MDMCFG3': '11',
    'MDMCFG2': '12',
    'DEVIATN': '15',
    'FREND0': '22',
  };
  
  double? _frequency;
  double? _bandwidth;
  double? _dataRate;
  double? _deviation;
  String? _modulation;
  String? _dataRaw;
  String _preset = 'FuriHalSubGhzPresetCustom';
  bool _dcFilter = false;
  bool _manchesterEncoding = false;
  int _syncMode = 0;
  int _version = 1;
  
  final List<String> _errors = [];
  
  FlipperSubGenerator setFrequency(double frequency) {
    _frequency = frequency;
    return this;
  }
  
  FlipperSubGenerator setBandwidth(double bandwidth) {
    _bandwidth = bandwidth;
    return this;
  }
  
  FlipperSubGenerator setDataRate(double dataRate) {
    _dataRate = dataRate;
    return this;
  }
  
  FlipperSubGenerator setDeviation(double deviation) {
    _deviation = deviation;
    return this;
  }
  
  FlipperSubGenerator setModulation(String modulation) {
    if (!_modulationTypes.containsKey(modulation)) {
      _errors.add('Unsupported modulation $modulation. Supported: ${_modulationTypes.keys.join(', ')}');
    }
    _modulation = modulation;
    return this;
  }
  
  FlipperSubGenerator setPreset(String preset) {
    _preset = preset;
    return this;
  }
  
  FlipperSubGenerator setDataRaw(String dataRaw) {
    _dataRaw = dataRaw;
    return this;
  }
  
  @override
  bool validate() {
    _errors.clear();
    
    if (_frequency == null) {
      _errors.add('Frequency is required');
    }
    
    if (_dataRaw == null || _dataRaw!.isEmpty) {
      _errors.add('Raw data is required');
    }
    
    return _errors.isEmpty;
  }
  
  @override
  String generate() {
    if (!validate()) {
      return _errors.join('\n');
    }
    
    final content = <String>[];
    content.add('Filetype: Flipper SubGhz RAW File');
    content.add('Version: $_version');
    content.add('Frequency: ${(_frequency! * 1000000).toInt()}');
    content.add('Preset: $_preset');
    
    if (_preset == 'FuriHalSubGhzPresetCustom') {
      content.add('Custom_preset_module: CC1101');
      content.add(_generateCustomPresetData());
    }
    
    content.add('Protocol: RAW');
    
    if (_dataRaw != null) {
      final rows = _splitStringByWords(_dataRaw!, 512);
      for (final row in rows) {
        content.add('RAW_Data: $row');
      }
    }
    
    return content.join('\n');
  }
  
  String _generateCustomPresetData() {
    final presetRow = <String>[];
    
    final calculator = CC1101Calculator();
    
    if (_bandwidth != null) {
      final bwHex = calculator.bandwidthToHex(_bandwidth!);
      presetRow.add(_configurationRegisters['MDMCFG4']!);
      presetRow.add('${bwHex}0'); // Default data rate exponent
    }
    
    if (_dataRate != null) {
      final drHex = calculator.dataRateToHex(_dataRate!);
      presetRow.add(_configurationRegisters['MDMCFG3']!);
      presetRow.add(drHex.m);
    }
    
    if (_deviation != null) {
      final devHex = calculator.deviationToHex(_deviation!);
      presetRow.add(_configurationRegisters['DEVIATN']!);
      presetRow.add('${devHex.e}${devHex.m}');
    }
    
    if (_modulation != null) {
      presetRow.add(_configurationRegisters['MDMCFG2']!);
      final modulationNum = _modulationTypes[_modulation]!;
      final mdmcfg2High = (modulationNum + (_dcFilter ? 8 : 0)).toRadixString(16).toUpperCase();
      final mdmcfg2Low = (_syncMode + (_manchesterEncoding ? 8 : 0)).toRadixString(16).toUpperCase();
      presetRow.add('$mdmcfg2High$mdmcfg2Low');
      
      presetRow.add(_configurationRegisters['FREND0']!);
      final frend0 = _modulation == 'ASK/OOK' ? '11' : '10';
      presetRow.add(frend0);
    }
    
    presetRow.add('00 00 00 C0 00 00 00 00 00 00');
    
    return 'Custom_preset_data: ${presetRow.join(' ')}';
  }
  
  List<String> _splitStringByWords(String text, int wordLimit) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];
    
    for (int i = 0; i < words.length; i += wordLimit) {
      final chunk = words.skip(i).take(wordLimit).join(' ');
      chunks.add(chunk);
    }
    
    return chunks;
  }
  
  @override
  List<String> getErrors() => List.unmodifiable(_errors);
}
```

### Фабрика генераторов
```dart
// lib/services/signal_generators/signal_generator_factory.dart
enum SignalFormat {
  flipperSub,
  tutJson,
  raw,
}

class SignalGeneratorFactory {
  static BaseSignalGenerator createGenerator(SignalFormat format) {
    switch (format) {
      case SignalFormat.flipperSub:
        return FlipperSubGenerator();
      case SignalFormat.tutJson:
        return TutJsonGenerator(); // Реализовать при необходимости
      case SignalFormat.raw:
        return RawSignalGenerator(); // Реализовать при необходимости
    }
  }
  
  static List<SignalFormat> getSupportedFormats() {
    return SignalFormat.values;
  }
}
```

## 2. Парсеры файлов

### Базовый парсер
```dart
// lib/services/file_parsers/base_file_parser.dart
abstract class BaseFileParser {
  SignalData parse(String content);
  bool canParse(String content);
  List<String> getSupportedExtensions();
}

class SignalData {
  final double? frequency;
  final String? raw;
  final String? binary;
  final String? smoothed;
  final double? dataRate;
  final double? deviation;
  final String? modulation;
  final double? pulseDuration;
  final int? samplesCount;
  final double? rxBandwidth;
  final String? preset;
  final String? protocol;
  final List<List<int>>? rawData;
  
  SignalData({
    this.frequency,
    this.raw,
    this.binary,
    this.smoothed,
    this.dataRate,
    this.deviation,
    this.modulation,
    this.pulseDuration,
    this.samplesCount,
    this.rxBandwidth,
    this.preset,
    this.protocol,
    this.rawData,
  });
}
```

### Парсер FlipperZero .sub файлов
```dart
// lib/services/file_parsers/flipper_sub_parser.dart
class FlipperSubParser extends BaseFileParser {
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
  
  @override
  bool canParse(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return false;
    
    final filetype = lines.first.split(':').length > 1 
        ? lines.first.split(':')[1].trim() 
        : '';
    
    return filetype.contains('Flipper SubGhz');
  }
  
  @override
  SignalData parse(String content) {
    final lines = content.split('\n');
    final filteredLines = lines
        .where((line) => !line.trim().startsWith('#'))
        .toList();
    
    if (filteredLines.isEmpty) {
      throw FormatException('Empty file content');
    }
    
    final filetype = filteredLines.first.split(':')[1].trim();
    if (!filetype.contains('Flipper SubGhz')) {
      throw FormatException('Invalid file type: $filetype');
    }
    
    final version = int.tryParse(filteredLines[1].split(':')[1].trim()) ?? 1;
    final frequency = int.tryParse(filteredLines[2].split(':')[1].trim()) ?? 0;
    
    if (version != 1) {
      throw FormatException('Unsupported .sub version: $version');
    }
    
    return _parseV1(filteredLines.skip(3).toList(), frequency.toDouble() / 1000000);
  }
  
  SignalData _parseV1(List<String> lines, double frequency) {
    final result = <String, dynamic>{};
    final rawData = <List<int>>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      
      final parts = line.split(':');
      if (parts.length < 2) continue;
      
      final key = parts[0].trim();
      final value = parts.sublist(1).join(':').trim();
      
      switch (key) {
        case 'Preset':
          if (_presets.containsKey(value)) {
            result.addAll(_presets[value]!);
          } else {
            throw FormatException('Unknown preset: $value');
          }
          break;
        case 'Protocol':
          result['protocol'] = value;
          break;
        case 'RAW_Data':
          final numbers = value.split(' ')
              .map((s) => int.tryParse(s) ?? 0)
              .toList();
          rawData.add(numbers);
          break;
        case 'Custom_preset_module':
        case 'Custom_preset_data':
          // Игнорируем кастомные пресеты
          break;
      }
    }
    
    return SignalData(
      frequency: frequency,
      preset: result['preset']?.toString(),
      modulation: _getModulationName(result['modulation']),
      rxBandwidth: result['rxBandwidth']?.toDouble(),
      dataRate: result['dataRate']?.toDouble(),
      deviation: result['deviation']?.toDouble(),
      protocol: result['protocol']?.toString(),
      rawData: rawData.isNotEmpty ? rawData : null,
    );
  }
  
  String _getModulationName(int? modulation) {
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
  
  @override
  List<String> getSupportedExtensions() => ['.sub'];
}
```

### Парсер TUT JSON
```dart
// lib/services/file_parsers/tut_json_parser.dart
class TutJsonParser extends BaseFileParser {
  @override
  bool canParse(String content) {
    try {
      final json = jsonDecode(content);
      return json is Map<String, dynamic> && 
             json.containsKey('frequency') && 
             json.containsKey('raw');
    } catch (e) {
      return false;
    }
  }
  
  @override
  SignalData parse(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    
    return SignalData(
      frequency: (json['frequency'] as num?)?.toDouble(),
      raw: json['raw'] as String?,
      binary: json['binary'] as String?,
      smoothed: json['smoothed'] as String?,
      dataRate: (json['dataRate'] as num?)?.toDouble(),
      deviation: (json['deviation'] as num?)?.toDouble(),
      modulation: json['modulation'] as String?,
      pulseDuration: (json['pulseDuration'] as num?)?.toDouble(),
      samplesCount: json['samplesCount'] as int?,
      rxBandwidth: (json['rxBandwidth'] as num?)?.toDouble(),
      preset: json['preset'] as String?,
    );
  }
  
  @override
  List<String> getSupportedExtensions() => ['.json'];
}
```

### Фабрика парсеров
```dart
// lib/services/file_parsers/file_parser_factory.dart
class FileParserFactory {
  static final List<BaseFileParser> _parsers = [
    FlipperSubParser(),
    TutJsonParser(),
  ];
  
  static BaseFileParser? getParserForContent(String content) {
    for (final parser in _parsers) {
      if (parser.canParse(content)) {
        return parser;
      }
    }
    return null;
  }
  
  static BaseFileParser? getParserForExtension(String extension) {
    for (final parser in _parsers) {
      if (parser.getSupportedExtensions().contains(extension.toLowerCase())) {
        return parser;
      }
    }
    return null;
  }
  
  static List<String> getSupportedExtensions() {
    final extensions = <String>{};
    for (final parser in _parsers) {
      extensions.addAll(parser.getSupportedExtensions());
    }
    return extensions.toList();
  }
}
```

## 3. Значения CC1101

```dart
// lib/services/cc1101/cc1101_values.dart
class CC1101Values {
  static const List<String> frequencies = [
    '300.00', '303.87', '304.25', '310.00', '315.00', '318.00',
    '390.00', '418.00', '433.07', '433.42', '433.92', '434.42',
    '434.77', '438.90', '868.35', '915.00', '916.80', '925.00',
  ];
  
  static const Map<String, double> dataRateLimits = {
    'min': 0.0248,
    'max': 1621.83,
  };
  
  static const Map<String, double> deviationLimits = {
    'min': 1.5869,
    'max': 380.8593,
  };
  
  static const List<Map<String, double>> frequencyRanges = [
    {'min': 300.0, 'max': 348.0},
    {'min': 387.0, 'max': 464.0},
    {'min': 779.0, 'max': 928.0},
  ];
  
  static const List<Map<String, String>> bandwidths = [
    {'float': '812.500', 'value': '812.50'},
    {'float': '650.000', 'value': '650.00'},
    {'float': '541.667', 'value': '541.67'},
    {'float': '464.286', 'value': '464.29'},
    {'float': '406.250', 'value': '406.25'},
    {'float': '325.000', 'value': '325.00'},
    {'float': '270.833', 'value': '270.83'},
    {'float': '232.143', 'value': '232.14'},
    {'float': '203.125', 'value': '203.13'},
    {'float': '162.500', 'value': '162.50'},
    {'float': '135.417', 'value': '135.41'},
    {'float': '116.071', 'value': '116.07'},
    {'float': '101.563', 'value': '101.56'},
    {'float': '81.250', 'value': '81.25'},
    {'float': '67.708', 'value': '67.70'},
    {'float': '58.036', 'value': '58.04'},
  ];
  
  static const List<Map<String, dynamic>> presets = [
    {
      'name': 'AM 270',
      'value': 'Ook270',
      'fzName': 'FuriHalSubGhzPresetOok270Async',
      'modulation': 'ASK/OOK (AM)',
      'bandwidth': '270.83 kHz',
      'dataRate': '3.79 kBaud',
    },
    {
      'name': 'AM 650',
      'value': 'Ook650',
      'fzName': 'FuriHalSubGhzPresetOok650Async',
      'modulation': 'ASK/OOK (AM)',
      'bandwidth': '650.00 kHz',
      'dataRate': '3.79 kBaud',
    },
    {
      'name': 'FM 2.38',
      'value': '2FSKDev238',
      'fzName': 'FuriHalSubGhzPreset2FSKDev238Async',
      'modulation': '2-FSK (FM)',
      'bandwidth': '270.83 kHz',
      'deviation': '2.38 kHz',
      'dataRate': '4.80 kBaud',
    },
    {
      'name': 'FM 47.6',
      'value': '2FSKDev476',
      'fzName': 'FuriHalSubGhzPreset2FSKDev476Async',
      'modulation': '2-FSK (FM)',
      'bandwidth': '270.83 kHz',
      'deviation': '47.6 kHz',
      'dataRate': '4.80 kBaud',
    },
  ];
  
  static bool isValidFrequency(double frequency) {
    for (final range in frequencyRanges) {
      if (frequency >= range['min']! && frequency <= range['max']!) {
        return true;
      }
    }
    return false;
  }
  
  static double? getClosestValidFrequency(double frequency) {
    double? closest;
    double minDifference = double.infinity;
    
    for (final range in frequencyRanges) {
      final min = range['min']!;
      final max = range['max']!;
      
      if (frequency < min) {
        final difference = min - frequency;
        if (difference < minDifference) {
          minDifference = difference;
          closest = min;
        }
      } else if (frequency > max) {
        final difference = frequency - max;
        if (difference < minDifference) {
          minDifference = difference;
          closest = max;
        }
      } else {
        return frequency; // Already valid
      }
    }
    
    return closest;
  }
}
```

## 4. Калькулятор CC1101

```dart
// lib/services/cc1101/cc1101_calculator.dart
class CC1101Calculator {
  static const double oscillatorFrequency = 26e6; // 26 MHz
  
  static const Map<String, String> registers = {
    'IOCFG2': '00',
    'IOCFG1': '01',
    'IOCFG0': '02',
    'FIFOTHR': '03',
    'SYNC1': '04',
    'SYNC0': '05',
    'PKTLEN': '06',
    'PKTCTRL1': '07',
    'PKTCTRL0': '08',
    'ADDR': '09',
    'CHANNR': '0A',
    'FSCTRL1': '0B',
    'FSCTRL0': '0C',
    'FREQ2': '0D',
    'FREQ1': '0E',
    'FREQ0': '0F',
    'MDMCFG4': '10',
    'MDMCFG3': '11',
    'MDMCFG2': '12',
    'MDMCFG1': '13',
    'MDMCFG0': '14',
    'DEVIATN': '15',
    'MCSM2': '16',
    'MCSM1': '17',
    'MCSM0': '18',
    'FOCCFG': '19',
    'BSCFG': '1A',
    'AGCCTRL2': '1B',
    'AGCCTRL1': '1C',
    'AGCCTRL0': '1D',
    'WOREVT1': '1E',
    'WOREVT0': '1F',
    'WORCTRL': '20',
    'FREND1': '21',
    'FREND0': '22',
    'FSCAL3': '23',
    'FSCAL2': '24',
    'FSCAL1': '25',
    'FSCAL0': '26',
    'RCCTRL1': '27',
    'RCCTRL0': '28',
    'FSTEST': '29',
    'PTEST': '2A',
    'AGCTEST': '2B',
    'TEST2': '2C',
    'TEST1': '2D',
    'TEST0': '2E',
  };
  
  // Конвертация Data Rate в hex
  DataRateHex dataRateToHex(double dataRate) {
    final drateRaw = dataRate * 1000;
    final drateE = (log(drateRaw * (1 << 20) / oscillatorFrequency) / ln2).floor() & 0x0F;
    final drateM = ((drateRaw * (1 << 28)) / (oscillatorFrequency * (1 << drateE)) - 256).round();
    
    return DataRateHex(
      e: drateE.toRadixString(16).toUpperCase(),
      m: drateM.toRadixString(16).toUpperCase(),
    );
  }
  
  // Конвертация Deviation в hex
  DeviationHex deviationToHex(double deviation) {
    final deviationRaw = deviation * 1000;
    final deviationE = (log(deviationRaw * (1 << 14) / oscillatorFrequency) / ln2).floor() & 0x07;
    final deviationM = ((deviationRaw * (1 << 17)) / (oscillatorFrequency * (1 << deviationE)) - 8).round() & 0x07;
    
    return DeviationHex(
      e: deviationE.toRadixString(16).toUpperCase(),
      m: deviationM.toRadixString(16).toUpperCase(),
    );
  }
  
  // Конвертация Bandwidth в hex
  String bandwidthToHex(double bandwidth) {
    final bandwidthList = [
      812000, 650000, 541000, 464000, 406000, 325000, 270000,
      232000, 203000, 162000, 135000, 116000, 102000, 81000,
      68000, 58000
    ];
    
    final bandwidthRaw = bandwidth * 1000;
    int bandwidthIndex = 15;
    
    for (int i = 0; i < 16; i++) {
      if (bandwidthRaw >= bandwidthList[i]) {
        bandwidthIndex = i;
        break;
      }
    }
    
    return bandwidthList[bandwidthIndex].toRadixString(16).toUpperCase();
  }
  
  // Конвертация Frequency в hex
  FrequencyHex frequencyToHex(double frequency) {
    final frequencyRaw = frequency * 1000000;
    final frequencyWord = frequencyRaw * (1 << 16) / oscillatorFrequency;
    
    final frequencyHigh = (frequencyWord / (1 << 16)).floor() & 0xFF;
    final frequencyMiddle = (frequencyWord / (1 << 8)).floor() & 0xFF;
    final frequencyLow = frequencyWord.floor() & 0xFF;
    
    return FrequencyHex(
      high: frequencyHigh.toRadixString(16).toUpperCase(),
      middle: frequencyMiddle.toRadixString(16).toUpperCase(),
      low: frequencyLow.toRadixString(16).toUpperCase(),
    );
  }
  
  // Парсинг конфигурации CC1101
  CC1101Config parseConfig(Map<String, String> config) {
    final frequency = _hexToFrequency(
      config[registers['FREQ2']] ?? '00',
      config[registers['FREQ1']] ?? '00',
      config[registers['FREQ0']] ?? '00',
    );
    
    final bandwidth = _hexToBandwidth(config[registers['MDMCFG4']] ?? '00');
    final modulation = _hexToModulation(config[registers['MDMCFG2']] ?? '00');
    final modulationName = _hexToModulationName(config[registers['MDMCFG2']] ?? '00');
    final dataRate = _hexToDataRate(
      config[registers['MDMCFG4']] ?? '00',
      config[registers['MDMCFG3']] ?? '00',
    );
    final deviation = _hexToDeviation(config[registers['DEVIATN']] ?? '00');
    
    return CC1101Config(
      frequency: frequency,
      bandwidth: bandwidth,
      modulation: modulation,
      modulationName: modulationName,
      dataRate: dataRate,
      deviation: deviation,
    );
  }
  
  double _hexToFrequency(String high, String middle, String low) {
    final frequencyHigh = int.parse(high, radix: 16);
    final frequencyMiddle = int.parse(middle, radix: 16);
    final frequencyLow = int.parse(low, radix: 16);
    
    final frequencyWord = (frequencyHigh << 16) | (frequencyMiddle << 8) | frequencyLow;
    final frequencyRaw = (frequencyWord * oscillatorFrequency) / (1 << 16);
    
    return frequencyRaw / 1000000;
  }
  
  double _hexToBandwidth(String value) {
    final registryValue = int.parse(value, radix: 16);
    final chanbwE = (registryValue >> 6) & 0x03;
    final chanbwM = (registryValue >> 4) & 0x03;
    
    return oscillatorFrequency / (8 * (4 + chanbwM) * pow(2, chanbwE));
  }
  
  int _hexToModulation(String value) {
    return (int.parse(value, radix: 16) >> 4) & 7;
  }
  
  String _hexToModulationName(String value) {
    final mod = _hexToModulation(value);
    switch (mod) {
      case 0:
        return '2-FSK';
      case 1:
        return 'GFSK';
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
  
  double _hexToDataRate(String mdmcfg4, String mdmcfg3) {
    final mdmcfg4Value = int.parse(mdmcfg4, radix: 16);
    final mdmcfg3Value = int.parse(mdmcfg3, radix: 16);
    final drateE = mdmcfg4Value & 0x0F;
    final drateM = mdmcfg3Value;
    
    return (oscillatorFrequency / pow(2, 28)) * (256 + drateM) * pow(2, drateE);
  }
  
  double _hexToDeviation(String deviatn) {
    final deviation = int.parse(deviatn, radix: 16);
    final deviationE = (deviation & 0x70) >> 4;
    final deviationM = deviation & 0x07;
    
    return (oscillatorFrequency / pow(2, 17)) * (8 + deviationM) * pow(2, deviationE);
  }
}

// Модели данных для калькулятора
class DataRateHex {
  final String e;
  final String m;
  
  DataRateHex({required this.e, required this.m});
}

class DeviationHex {
  final String e;
  final String m;
  
  DeviationHex({required this.e, required this.m});
}

class FrequencyHex {
  final String high;
  final String middle;
  final String low;
  
  FrequencyHex({required this.high, required this.middle, required this.low});
}

class CC1101Config {
  final double frequency;
  final double bandwidth;
  final int modulation;
  final String modulationName;
  final double dataRate;
  final double deviation;
  
  CC1101Config({
    required this.frequency,
    required this.bandwidth,
    required this.modulation,
    required this.modulationName,
    required this.dataRate,
    required this.deviation,
  });
}
```

## Интеграция с существующим кодом

### Обновление BleProvider
```dart
// Добавить в BleProvider методы для работы с файлами
class BleProvider extends ChangeNotifier {
  // ... существующий код ...
  
  Future<SignalData?> parseSignalFile(String filePath) async {
    try {
      final content = await readFileContent(filePath);
      final parser = FileParserFactory.getParserForContent(content);
      
      if (parser != null) {
        return parser.parse(content);
      }
      
      return null;
    } catch (e) {
      _log('error', 'Failed to parse signal file', details: 'Error: $e');
      return null;
    }
  }
  
  Future<String?> generateSignalFile(SignalFormat format, SignalData data) async {
    try {
      final generator = SignalGeneratorFactory.createGenerator(format);
      
      // Настройка генератора на основе данных
      if (data.frequency != null) {
        (generator as FlipperSubGenerator).setFrequency(data.frequency!);
      }
      
      if (data.raw != null) {
        (generator as FlipperSubGenerator).setDataRaw(data.raw!);
      }
      
      return generator.generate();
    } catch (e) {
      _log('error', 'Failed to generate signal file', details: 'Error: $e');
      return null;
    }
  }
}
```

## Задачи для реализации

### Этап 1: Базовая инфраструктура (2-3 дня)
- [ ] Создать базовые классы и интерфейсы
- [ ] Реализовать CC1101Calculator
- [ ] Реализовать CC1101Values
- [ ] Создать модели данных (SignalData, CC1101Config)

### Этап 2: Генераторы (2-3 дня)
- [ ] Реализовать FlipperSubGenerator
- [ ] Создать SignalGeneratorFactory
- [ ] Добавить валидацию данных
- [ ] Протестировать генерацию файлов

### Этап 3: Парсеры (2-3 дня)
- [ ] Реализовать FlipperSubParser
- [ ] Реализовать TutJsonParser
- [ ] Создать FileParserFactory
- [ ] Добавить обработку ошибок

### Этап 4: Интеграция (1-2 дня)
- [ ] Интегрировать с BleProvider
- [ ] Добавить в UI возможность экспорта/импорта
- [ ] Протестировать полный цикл работы
- [ ] Добавить обработку ошибок в UI

### Этап 5: Расширение (1-2 дня)
- [ ] Добавить поддержку других форматов
- [ ] Создать дополнительные генераторы
- [ ] Добавить валидацию файлов
- [ ] Оптимизировать производительность

## Заключение

Этот план обеспечивает полный перенос критически важной логики из VueJS в Flutter с возможностью легкого расширения новыми форматами и функциями. Архитектура построена на принципах модульности и расширяемости, что позволит легко добавлять новые генераторы и парсеры в будущем.

