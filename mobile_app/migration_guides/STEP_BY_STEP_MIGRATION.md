# Пошаговый план переноса VueJS в Android (Flutter)

## Этап 1: Подготовка и анализ (1-2 дня)

### 1.1 Изучение текущей архитектуры
- [x] Проанализировать VueJS приложение
- [x] Изучить текущую Android архитектуру
- [x] Создать план миграции
- [ ] Создать диаграммы архитектуры

### 1.2 Подготовка инструментов
- [ ] Настроить среду разработки
- [ ] Создать ветку для миграции
- [ ] Настроить тестирование

## Этап 2: Базовая инфраструктура (2-3 дня)

### 2.1 Перенос основной логики
- [ ] Создать CC1101Calculator и CC1101Values
- [ ] Реализовать генераторы сигналов (FlipperSubGenerator)
- [ ] Реализовать парсеры файлов (FlipperSubParser, TutJsonParser)
- [ ] Создать фабрики для генераторов и парсеров

**Новые файлы:**
- `lib/services/cc1101/cc1101_calculator.dart`
- `lib/services/cc1101/cc1101_values.dart`
- `lib/services/signal_generators/flipper_sub_generator.dart`
- `lib/services/file_parsers/flipper_sub_parser.dart`
- `lib/services/file_parsers/tut_json_parser.dart`

### 2.2 Создание базовых моделей
```dart
// models/device_state.dart
class DeviceState {
  final bool isConnected;
  final String? deviceName;
  final int? freeHeap;
  final List<CC1101Module> modules;
  
  DeviceState({
    required this.isConnected,
    this.deviceName,
    this.freeHeap,
    required this.modules,
  });
}

// models/cc1101_module.dart
class CC1101Module {
  final int id;
  final String mode;
  final Map<String, dynamic> settings;
  
  CC1101Module({
    required this.id,
    required this.mode,
    required this.settings,
  });
}

// models/signal_config.dart
class SignalConfig {
  final double frequency;
  final String preset;
  final String modulation;
  final double? bandwidth;
  final double? dataRate;
  final double? deviation;
  
  SignalConfig({
    required this.frequency,
    required this.preset,
    required this.modulation,
    this.bandwidth,
    this.dataRate,
    this.deviation,
  });
}
```

### 2.2 Создание сервисного слоя
```dart
// services/device_service.dart
abstract class DeviceService {
  Future<void> connect();
  Future<void> disconnect();
  Future<DeviceState> getState();
  Future<void> sendCommand(String command);
}

// services/signal_service.dart
abstract class SignalService {
  Future<List<DetectedSignal>> scanFrequencies(int module, int minRssi);
  Future<void> startRecording(int module, SignalConfig config);
  Future<void> stopRecording(int module);
  Future<void> transmitSignal(int module, String data);
}

// services/file_service.dart
abstract class FileService {
  Future<List<FileItem>> getFiles(String path);
  Future<String> readFile(String path);
  Future<void> writeFile(String path, String content);
  Future<void> deleteFile(String path);
  Future<void> createDirectory(String path);
}
```

### 2.3 Обновление провайдеров
- [ ] Создать единый AppStateProvider
- [ ] Рефакторить BleProvider
- [ ] Добавить новые провайдеры для сигналов и файлов

## Этап 3: Перенос основных экранов (3-4 дня)

### 3.1 Улучшение Home Screen
- [ ] Добавить кнопку "Update state"
- [ ] Создать DebugInfoWidget
- [ ] Улучшить отображение состояния устройства
- [ ] Добавить анимации

**Файлы для изменения:**
- `lib/screens/home_screen.dart`
- `lib/widgets/debug_info_widget.dart` (новый)

### 3.2 Создание Record Screen
- [ ] Создать FrequencyDetectorWidget
- [ ] Создать ModuleSettingsWidget
- [ ] Создать RecordButtonWidget
- [ ] Создать RecordedFilesWidget
- [ ] Создать новый RecordScreen

**Новые файлы:**
- `lib/screens/record_screen.dart`
- `lib/widgets/frequency_detector_widget.dart`
- `lib/widgets/module_settings_widget.dart`
- `lib/widgets/record_button_widget.dart`
- `lib/widgets/recorded_files_widget.dart`

### 3.3 Создание Transmit Screen
- [ ] Создать TransmitModuleSettingsWidget
- [ ] Создать TransmitFileWidget
- [ ] Создать QuickTransmitWidget
- [ ] Создать TransmitStatusWidget
- [ ] Создать новый TransmitScreen

**Новые файлы:**
- `lib/screens/transmit_screen.dart`
- `lib/widgets/transmit_module_settings_widget.dart`
- `lib/widgets/transmit_file_widget.dart`
- `lib/widgets/quick_transmit_widget.dart`
- `lib/widgets/transmit_status_widget.dart`

### 3.4 Улучшение Files Screen
- [ ] Создать EnhancedFileExplorerWidget
- [ ] Создать FileUploadWidget
- [ ] Создать FileViewerDialog
- [ ] Улучшить существующий FilesScreen

**Файлы для изменения:**
- `lib/screens/files_screen.dart`
- `lib/widgets/enhanced_file_explorer_widget.dart` (новый)
- `lib/widgets/file_upload_widget.dart` (новый)
- `lib/widgets/file_viewer_dialog.dart` (новый)

### 3.5 Создание Editor Screen
- [ ] Создать SignalEditorWidget
- [ ] Создать FilePickerDialog
- [ ] Создать SignalTemplatesWidget
- [ ] Создать новый EditorScreen

**Новые файлы:**
- `lib/screens/editor_screen.dart`
- `lib/widgets/signal_editor_widget.dart`
- `lib/widgets/file_picker_dialog.dart`
- `lib/widgets/signal_templates_widget.dart`

## Этап 4: Интеграция и тестирование (2-3 дня)

### 4.1 Обновление навигации
```dart
// main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppStateProvider()),
        ChangeNotifierProvider(create: (context) => BleProvider()),
        ChangeNotifierProvider(create: (context) => LogProvider()),
      ],
      child: MaterialApp(
        title: 'Evil Crow RF v2 Controller',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}

// screens/main_screen.dart
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const RecordScreen(), // Новый экран
    const TransmitScreen(), // Новый экран
    const FilesScreen(),
    const EditorScreen(), // Новый экран
    const SignalScannerScreen(),
    const DebugScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fiber_manual_record), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Transmit'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: 'Editor'),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: 'Debug'),
        ],
      ),
    );
  }
}
```

### 4.2 Тестирование функций
- [ ] Тестирование подключения к устройству
- [ ] Тестирование записи сигналов
- [ ] Тестирование передачи сигналов
- [ ] Тестирование файлового менеджера
- [ ] Тестирование редактора сигналов

### 4.3 Исправление багов
- [ ] Исправить ошибки в навигации
- [ ] Исправить ошибки в передаче данных
- [ ] Исправить ошибки в UI
- [ ] Оптимизировать производительность

## Этап 5: Улучшения и оптимизация (2-3 дня)

### 5.1 Улучшение UX
- [ ] Добавить Material Design 3
- [ ] Добавить анимации
- [ ] Добавить темную тему
- [ ] Улучшить адаптивность

### 5.2 Оптимизация производительности
- [ ] Добавить кеширование
- [ ] Оптимизировать BLE протокол
- [ ] Добавить ленивую загрузку
- [ ] Оптимизировать память

### 5.3 Добавление новых функций
- [ ] Добавить экспорт/импорт данных
- [ ] Добавить шаблоны сигналов
- [ ] Добавить историю операций
- [ ] Добавить поиск по файлам

## Этап 6: Финальное тестирование (1-2 дня)

### 6.1 Полное тестирование
- [ ] Тестирование всех экранов
- [ ] Тестирование всех функций
- [ ] Тестирование на разных устройствах
- [ ] Тестирование производительности

### 6.2 Документация
- [ ] Обновить README
- [ ] Создать пользовательскую документацию
- [ ] Создать документацию для разработчиков

### 6.3 Подготовка к релизу
- [ ] Создать релизную сборку
- [ ] Провести финальное тестирование
- [ ] Подготовить changelog

## Рекомендации по реализации

### Приоритеты
1. **Высокий приоритет:** Record Screen, Transmit Screen, улучшение Files Screen
2. **Средний приоритет:** Editor Screen, улучшения UX
3. **Низкий приоритет:** Дополнительные функции, оптимизации

### Подход к разработке
1. **Итеративный подход:** Реализовывать по одному экрану за раз
2. **Тестирование:** Тестировать каждый экран после реализации
3. **Обратная совместимость:** Сохранять совместимость с существующим кодом
4. **Документация:** Документировать изменения по мере разработки

### Советы по реализации
1. **Начните с простого:** Реализуйте базовую функциональность, затем добавляйте улучшения
2. **Используйте существующий код:** Переиспользуйте существующие компоненты где это возможно
3. **Тестируйте часто:** Тестируйте на реальном устройстве ESP32
4. **Обрабатывайте ошибки:** Добавляйте обработку ошибок с самого начала

## Ожидаемые результаты

После завершения миграции приложение будет иметь:
- Полную функциональность VueJS версии
- Улучшенный UX с Material Design 3
- Лучшую производительность
- Более надежную архитектуру
- Расширенные возможности

## Временные рамки

Общее время миграции: **10-15 дней**
- Подготовка: 1-2 дня
- Базовая инфраструктура: 2-3 дня
- Перенос экранов: 3-4 дня
- Интеграция и тестирование: 2-3 дня
- Улучшения: 2-3 дня
- Финальное тестирование: 1-2 дня

## Риски и митигация

### Возможные риски
1. **Несовместимость протоколов:** ESP32 может использовать другой протокол
2. **Производительность BLE:** Ограничения BLE могут влиять на функциональность
3. **Сложность UI:** Некоторые функции могут быть сложными для реализации

### Планы митигации
1. **Тестирование протокола:** Тщательно тестировать протокол общения
2. **Оптимизация данных:** Оптимизировать передачу данных
3. **Упрощение UI:** Упрощать сложные функции при необходимости
