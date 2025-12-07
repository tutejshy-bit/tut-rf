/// Предопределенные значения для модуля CC1101
/// Содержит частоты, полосы пропускания, пресеты и другие константы
class CC1101Values {
  /// Список поддерживаемых частот в MHz
  static const List<String> frequencies = [
    '300.00', '303.87', '304.25', '310.00', '315.00', '318.00',
    '390.00', '418.00', '433.07', '433.42', '433.92', '434.42',
    '434.77', '438.90', '868.35', '915.00', '916.80', '925.00',
  ];
  
  /// Ограничения для скорости передачи данных
  static const Map<String, double> dataRateLimits = {
    'min': 0.0248,  // Минимальная скорость в kBaud
    'max': 1621.83, // Максимальная скорость в kBaud
  };
  
  /// Ограничения для девиации частоты
  static const Map<String, double> deviationLimits = {
    'min': 1.5869,  // Минимальная девиация в kHz
    'max': 380.8593, // Максимальная девиация в kHz
  };
  
  /// Допустимые диапазоны частот
  static const List<Map<String, double>> frequencyRanges = [
    {'min': 300.0, 'max': 348.0},
    {'min': 387.0, 'max': 464.0},
    {'min': 779.0, 'max': 928.0},
  ];
  
  /// Доступные полосы пропускания
  /// float - точное значение для расчетов
  /// value - отображаемое значение
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
  
  /// Предопределенные пресеты для быстрой настройки
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
  
  /// Типы модуляции
  static const Map<String, int> modulationTypes = {
    '2-FSK': 0,
    'GFSK': 1,
    'ASK/OOK': 3,
    '4-FSK': 4,
    'MSK': 7,
  };
  
  /// Обратный маппинг: номер модуляции -> название
  static const Map<int, String> modulationNames = {
    0: '2-FSK',
    1: 'GFSK',
    3: 'ASK/OOK',
    4: '4-FSK',
    7: 'MSK',
  };
  
  /// Проверка валидности частоты
  /// [frequency] - частота в MHz
  /// Возвращает true если частота находится в допустимом диапазоне
  static bool isValidFrequency(double frequency) {
    for (final range in frequencyRanges) {
      if (frequency >= range['min']! && frequency <= range['max']!) {
        return true;
      }
    }
    return false;
  }
  
  /// Получение float значения частоты по строковому значению
  static double? getFrequencyFloat(String value) {
    try {
      if (frequencies.contains(value)) {
        return double.parse(value);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Получение ближайшей допустимой частоты
  /// [frequency] - исходная частота в MHz
  /// Возвращает ближайшую допустимую частоту или исходную если она валидна
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
        return frequency; // Уже валидна
      }
    }
    
    return closest;
  }
  
  /// Проверка валидности скорости передачи данных
  /// [dataRate] - скорость в kBaud
  /// Возвращает true если скорость в допустимом диапазоне
  static bool isValidDataRate(double dataRate) {
    return dataRate >= dataRateLimits['min']! && 
           dataRate <= dataRateLimits['max']!;
  }
  
  /// Проверка валидности девиации частоты
  /// [deviation] - девиация в kHz
  /// Возвращает true если девиация в допустимом диапазоне
  static bool isValidDeviation(double deviation) {
    return deviation >= deviationLimits['min']! && 
           deviation <= deviationLimits['max']!;
  }
  
  /// Получение ограниченного значения скорости передачи данных
  /// [dataRate] - исходная скорость в kBaud
  /// Возвращает значение в пределах допустимого диапазона
  static double limitDataRate(double dataRate) {
    if (dataRate < dataRateLimits['min']!) {
      return dataRateLimits['min']!;
    }
    if (dataRate > dataRateLimits['max']!) {
      return dataRateLimits['max']!;
    }
    return dataRate;
  }
  
  /// Получение ограниченного значения девиации частоты
  /// [deviation] - исходная девиация в kHz
  /// Возвращает значение в пределах допустимого диапазона
  static double limitDeviation(double deviation) {
    if (deviation < deviationLimits['min']!) {
      return deviationLimits['min']!;
    }
    if (deviation > deviationLimits['max']!) {
      return deviationLimits['max']!;
    }
    return deviation;
  }
  
  /// Получение пресета по значению
  /// [value] - значение пресета (например, 'Ook270')
  /// Возвращает пресет или null если не найден
  static Map<String, dynamic>? getPresetByValue(String value) {
    try {
      return presets.firstWhere((preset) => preset['value'] == value);
    } catch (e) {
      return null;
    }
  }
  
  /// Получение пресета по FZ имени
  /// [fzName] - имя пресета для FlipperZero (например, 'FuriHalSubGhzPresetOok270Async')
  /// Возвращает пресет или null если не найден
  static Map<String, dynamic>? getPresetByFzName(String fzName) {
    try {
      return presets.firstWhere((preset) => preset['fzName'] == fzName);
    } catch (e) {
      return null;
    }
  }
  
  /// Получение названия модуляции по номеру
  /// [modulation] - номер модуляции
  /// Возвращает название модуляции или 'Unknown'
  static String getModulationName(int modulation) {
    return modulationNames[modulation] ?? 'Unknown';
  }
  
  /// Получение номера модуляции по названию
  /// [name] - название модуляции
  /// Возвращает номер модуляции или null если не найден
  static int? getModulationNumber(String name) {
    return modulationTypes[name];
  }
  
  /// Получение списка названий модуляций
  /// Возвращает список доступных названий модуляций
  static List<String> getModulationNames() {
    return modulationTypes.keys.toList();
  }
  
  /// Получение списка значений полос пропускания
  /// Возвращает список значений для отображения
  static List<String> getBandwidthValues() {
    return bandwidths.map((bw) => bw['value']!).toList();
  }
  
  /// Получение точного значения полосы пропускания
  /// [displayValue] - отображаемое значение (например, '270.83')
  /// Возвращает точное значение для расчетов
  static double? getBandwidthFloat(String displayValue) {
    try {
      final bandwidth = bandwidths.firstWhere(
        (bw) => bw['value'] == displayValue
      );
      return double.parse(bandwidth['float']!);
    } catch (e) {
      return null;
    }
  }
}
