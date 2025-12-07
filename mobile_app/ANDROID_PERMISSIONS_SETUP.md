# 🔐 Настройка Bluetooth разрешений для Android

## 📱 Требования для BLE сканирования

### Android 12+ (API 31+)
- `BLUETOOTH_SCAN` - для сканирования Bluetooth устройств
- `BLUETOOTH_CONNECT` - для подключения к устройствам
- `BLUETOOTH_ADVERTISE` - для рекламы (если нужно)

### Android 11 и ниже
- `BLUETOOTH` - базовое разрешение
- `BLUETOOTH_ADMIN` - административные функции
- `ACCESS_FINE_LOCATION` - точное местоположение (требуется для сканирования)

## ✅ Что уже настроено

### 1. AndroidManifest.xml
```xml
<!-- Bluetooth permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />

<!-- Android 12+ specific permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
                 android:usesPermissionFlags="neverForLocation"
                 tools:targetApi="s" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />

<!-- Location permissions for older Android -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### 2. BLE Provider (Dart код)
```dart
Future<void> _requestPermissions() async {
  // Basic Bluetooth permissions
  if (await Permission.bluetooth.isDenied) {
    await Permission.bluetooth.request();
  }
  
  // Android 12+ specific permissions
  if (await Permission.bluetoothScan.isDenied) {
    await Permission.bluetoothScan.request();
  }
  
  if (await Permission.bluetoothConnect.isDenied) {
    await Permission.bluetoothConnect.request();
  }
  
  if (await Permission.bluetoothAdvertise.isDenied) {
    await Permission.bluetoothAdvertise.request();
  }
  
  // Location permission (required for scanning)
  if (await Permission.location.isDenied) {
    await Permission.location.request();
  }
}
```

## 🚀 Как это работает

### 1. При запуске приложения
- Автоматически запрашиваются все необходимые разрешения
- Проверяется статус каждого разрешения
- Показывается предупреждение, если что-то не разрешено

### 2. Перед сканированием
- Дополнительная проверка разрешений
- Сканирование не запускается без нужных прав
- Пользователь получает понятное сообщение об ошибке

### 3. Динамические разрешения
- Разрешения запрашиваются только при необходимости
- Пользователь может отказаться и попробовать позже
- Статус разрешений отображается в UI

## 🔧 Устранение проблем

### Если сканирование не работает:

1. **Проверьте разрешения в настройках Android:**
   - Настройки → Приложения → evilcrow_rf2_controller → Разрешения
   - Убедитесь, что все Bluetooth разрешения включены

2. **Включите Bluetooth и местоположение:**
   - Bluetooth должен быть включен
   - GPS/местоположение должно быть включено

3. **Перезапустите приложение:**
   - Закройте приложение полностью
   - Запустите заново
   - Подтвердите все запрашиваемые разрешения

### Для разработчиков:

1. **Очистите проект:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Переустановите приложение:**
   - Удалите приложение с устройства
   - Установите заново

3. **Проверьте логи:**
   ```bash
   flutter run -d RFCNC06BZYJ --verbose
   ```

## 📋 Список разрешений по версиям Android

| Android Version | API Level | Требуемые разрешения |
|----------------|-----------|---------------------|
| 12+ | 31+ | BLUETOOTH_SCAN, BLUETOOTH_CONNECT |
| 11 | 30 | BLUETOOTH, ACCESS_FINE_LOCATION |
| 10 | 29 | BLUETOOTH, ACCESS_FINE_LOCATION |
| 9 | 28 | BLUETOOTH, ACCESS_FINE_LOCATION |
| 8 | 26 | BLUETOOTH, ACCESS_FINE_LOCATION |

## 🎯 Результат

После правильной настройки:
- ✅ BLE сканирование работает на всех версиях Android
- ✅ Автоматический запрос разрешений
- ✅ Проверка прав перед выполнением операций
- ✅ Понятные сообщения об ошибках для пользователя




