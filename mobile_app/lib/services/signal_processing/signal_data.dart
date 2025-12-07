/// Модель данных для работы с сигналами
/// Содержит все необходимые параметры для записи, передачи и анализа сигналов
class SignalData {
  /// Частота в MHz
  final double? frequency;
  
  /// Сырые данные сигнала (строковое представление)
  final String? raw;
  
  /// Бинарные данные сигнала
  final String? binary;
  
  /// Сглаженные данные сигнала
  final String? smoothed;
  
  /// Скорость передачи данных в kBaud
  final double? dataRate;
  
  /// Девиация частоты в kHz
  final double? deviation;
  
  /// Тип модуляции (название)
  final String? modulation;
  
  /// Длительность импульса в микросекундах
  final double? pulseDuration;
  
  /// Количество выборок
  final int? samplesCount;
  
  /// Полоса пропускания приемника в kHz
  final double? rxBandwidth;
  
  /// Пресет для настройки
  final String? preset;
  
  /// Протокол передачи
  final String? protocol;
  
  /// Сырые данные в виде массива чисел
  final List<List<int>>? rawData;
  
  /// Название файла (если применимо)
  final String? filename;
  
  /// Дата создания/записи
  final DateTime? dateCreated;
  
  /// Размер файла в байтах
  final int? fileSize;
  
  /// Метаданные сигнала
  final Map<String, dynamic>? metadata;
  
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
    this.filename,
    this.dateCreated,
    this.fileSize,
    this.metadata,
  });
  
  /// Создание копии с изменениями
  SignalData copyWith({
    double? frequency,
    String? raw,
    String? binary,
    String? smoothed,
    double? dataRate,
    double? deviation,
    String? modulation,
    double? pulseDuration,
    int? samplesCount,
    double? rxBandwidth,
    String? preset,
    String? protocol,
    List<List<int>>? rawData,
    String? filename,
    DateTime? dateCreated,
    int? fileSize,
    Map<String, dynamic>? metadata,
  }) {
    return SignalData(
      frequency: frequency ?? this.frequency,
      raw: raw ?? this.raw,
      binary: binary ?? this.binary,
      smoothed: smoothed ?? this.smoothed,
      dataRate: dataRate ?? this.dataRate,
      deviation: deviation ?? this.deviation,
      modulation: modulation ?? this.modulation,
      pulseDuration: pulseDuration ?? this.pulseDuration,
      samplesCount: samplesCount ?? this.samplesCount,
      rxBandwidth: rxBandwidth ?? this.rxBandwidth,
      preset: preset ?? this.preset,
      protocol: protocol ?? this.protocol,
      rawData: rawData ?? this.rawData,
      filename: filename ?? this.filename,
      dateCreated: dateCreated ?? this.dateCreated,
      fileSize: fileSize ?? this.fileSize,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Проверка валидности данных сигнала
  bool get isValid {
    // Минимальные требования для валидного сигнала
    if (frequency == null || frequency! <= 0) return false;
    if (raw == null && rawData == null) return false;
    
    // Проверка диапазона частоты
    if (frequency! < 300 || frequency! > 928) return false;
    
    return true;
  }
  
  /// Получение типа файла на основе расширения
  String? get fileType {
    if (filename == null) return null;
    
    final extension = filename!.split('.').last.toLowerCase();
    switch (extension) {
      case 'sub':
        return 'FlipperZero SubGhz';
      case 'json':
        return 'TUT JSON';
      case 'raw':
        return 'RAW Data';
      default:
        return 'Unknown';
    }
  }
  
  /// Получение отображаемого размера файла
  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = fileSize!.toDouble();
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
  
  /// Получение отформатированной даты
  String get formattedDate {
    if (dateCreated == null) return 'Unknown';
    
    return '${dateCreated!.day.toString().padLeft(2, '0')}/'
           '${dateCreated!.month.toString().padLeft(2, '0')}/'
           '${dateCreated!.year} '
           '${dateCreated!.hour.toString().padLeft(2, '0')}:'
           '${dateCreated!.minute.toString().padLeft(2, '0')}';
  }
  
  /// Получение краткой информации о сигнале
  String get summary {
    final parts = <String>[];
    
    if (frequency != null) {
      parts.add('${frequency!.toStringAsFixed(2)} MHz');
    }
    
    if (modulation != null) {
      parts.add(modulation!);
    }
    
    if (dataRate != null) {
      parts.add('${dataRate!.toStringAsFixed(1)} kBaud');
    }
    
    if (deviation != null) {
      parts.add('±${deviation!.toStringAsFixed(1)} kHz');
    }
    
    return parts.join(', ');
  }
  
  /// Конвертация в Map для JSON сериализации
  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'raw': raw,
      'binary': binary,
      'smoothed': smoothed,
      'dataRate': dataRate,
      'deviation': deviation,
      'modulation': modulation,
      'pulseDuration': pulseDuration,
      'samplesCount': samplesCount,
      'rxBandwidth': rxBandwidth,
      'preset': preset,
      'protocol': protocol,
      'rawData': rawData,
      'filename': filename,
      'dateCreated': dateCreated?.toIso8601String(),
      'fileSize': fileSize,
      'metadata': metadata,
    };
  }
  
  /// Создание из Map (для десериализации JSON)
  factory SignalData.fromJson(Map<String, dynamic> json) {
    return SignalData(
      frequency: json['frequency']?.toDouble(),
      raw: json['raw'] as String?,
      binary: json['binary'] as String?,
      smoothed: json['smoothed'] as String?,
      dataRate: json['dataRate']?.toDouble(),
      deviation: json['deviation']?.toDouble(),
      modulation: json['modulation'] as String?,
      pulseDuration: json['pulseDuration']?.toDouble(),
      samplesCount: json['samplesCount'] as int?,
      rxBandwidth: json['rxBandwidth']?.toDouble(),
      preset: json['preset'] as String?,
      protocol: json['protocol'] as String?,
      rawData: json['rawData'] != null 
          ? List<List<int>>.from(
              json['rawData'].map((row) => List<int>.from(row))
            )
          : null,
      filename: json['filename'] as String?,
      dateCreated: json['dateCreated'] != null 
          ? DateTime.parse(json['dateCreated'])
          : null,
      fileSize: json['fileSize'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  @override
  String toString() {
    return 'SignalData('
        'frequency: $frequency MHz, '
        'modulation: $modulation, '
        'dataRate: $dataRate kBaud, '
        'deviation: $deviation kHz, '
        'filename: $filename)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SignalData &&
        other.frequency == frequency &&
        other.raw == raw &&
        other.binary == binary &&
        other.smoothed == smoothed &&
        other.dataRate == dataRate &&
        other.deviation == deviation &&
        other.modulation == modulation &&
        other.preset == preset &&
        other.protocol == protocol &&
        other.filename == filename;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      frequency,
      raw,
      binary,
      smoothed,
      dataRate,
      deviation,
      modulation,
      preset,
      protocol,
      filename,
    );
  }
}

/// Типы файлов сигналов
enum SignalFileType {
  flipperSub('.sub', 'FlipperZero SubGhz'),
  tutJson('.json', 'TUT JSON'),
  raw('.raw', 'RAW Data'),
  unknown('', 'Unknown');
  
  const SignalFileType(this.extension, this.description);
  
  final String extension;
  final String description;
  
  /// Определение типа файла по расширению
  static SignalFileType fromExtension(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    for (final type in SignalFileType.values) {
      if (type.extension == '.$extension') {
        return type;
      }
    }
    
    return SignalFileType.unknown;
  }
}

/// Конфигурация для записи сигнала
class RecordConfig {
  final double frequency;
  final String? preset;
  final int module;
  final String? modulation;
  final double? bandwidth;
  final double? deviation;
  final double? dataRate;
  final double? rxBandwidth;
  final bool advancedMode;
  
  RecordConfig({
    required this.frequency,
    this.preset,
    required this.module,
    this.modulation,
    this.bandwidth,
    this.deviation,
    this.dataRate,
    this.rxBandwidth,
    this.advancedMode = false,
  });
  
  /// Создание копии с изменениями
  RecordConfig copyWith({
    double? frequency,
    String? preset,
    int? module,
    String? modulation,
    double? bandwidth,
    double? deviation,
    double? dataRate,
    double? rxBandwidth,
    bool? advancedMode,
  }) {
    return RecordConfig(
      frequency: frequency ?? this.frequency,
      preset: preset ?? this.preset,
      module: module ?? this.module,
      modulation: modulation ?? this.modulation,
      bandwidth: bandwidth ?? this.bandwidth,
      deviation: deviation ?? this.deviation,
      dataRate: dataRate ?? this.dataRate,
      rxBandwidth: rxBandwidth ?? this.rxBandwidth,
      advancedMode: advancedMode ?? this.advancedMode,
    );
  }
  
  /// Создание из SignalData
  factory RecordConfig.fromSignalData(SignalData signal, int module) {
    return RecordConfig(
      frequency: signal.frequency ?? 433.92,
      preset: signal.preset,
      module: module,
      modulation: signal.modulation,
      bandwidth: signal.rxBandwidth,
      deviation: signal.deviation,
      dataRate: signal.dataRate,
      advancedMode: signal.modulation != null,
    );
  }
  
  /// Конвертация в Map для передачи на устройство
  Map<String, dynamic> toDeviceParams() {
    final params = <String, dynamic>{
      'frequency': frequency,
      'module': module,
    };
    
    if (advancedMode) {
      if (modulation != null) params['modulation'] = modulation;
      if (bandwidth != null) params['bandwidth'] = bandwidth;
      if (deviation != null) params['deviation'] = deviation;
      if (dataRate != null) params['dataRate'] = dataRate;
    } else {
      if (preset != null) params['preset'] = preset;
    }
    
    return params;
  }
  
  @override
  String toString() {
    return 'RecordConfig('
        'frequency: $frequency MHz, '
        'module: $module, '
        'preset: $preset, '
        'modulation: $modulation)';
  }
}
