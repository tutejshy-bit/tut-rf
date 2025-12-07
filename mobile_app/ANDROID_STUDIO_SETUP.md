# Настройка Android Studio для нового Flutter 3.35.2

## Проблема
Android Studio все еще пытается использовать старую папку Flutter (`C:\flutter`), которая имеет проблемы с правами доступа.

## Решение

### 1. Обновить путь к Flutter в Android Studio

1. **Откройте Android Studio**
2. **Перейдите в настройки:**
   - Windows/Linux: `File → Settings` (или `Ctrl+Alt+S`)
   - macOS: `Android Studio → Preferences`

3. **Найдите настройки Flutter:**
   - В левом меню выберите `Languages & Frameworks → Flutter`
   - Или найдите "Flutter" в поиске настроек

4. **Обновите путь к Flutter SDK:**
   - В поле "Flutter SDK path" измените путь с:
     ```
     C:\flutter
     ```
   - На новый путь:
     ```
     C:\flutter_new\flutter
     ```

5. **Нажмите "Apply" и "OK"**

### 2. Перезапуск Android Studio

После изменения настроек:
1. Закройте Android Studio
2. Откройте заново
3. Дождитесь завершения индексации

### 3. Проверка настройки

В Android Studio выполните:
1. **Откройте Terminal** (`View → Tool Windows → Terminal`)
2. **Выполните команду:**
   ```bash
   flutter --version
   ```
3. **Должна показаться версия 3.35.2**

### 4. Обновление проекта

В терминале Android Studio выполните:
```bash
flutter clean
flutter pub get
```

### 5. Альтернативный способ (если настройки не работают)

Если настройки Flutter не отображаются в Android Studio:

1. **Удалите старую папку Flutter:**
   ```powershell
   # В PowerShell от администратора
   Remove-Item "C:\flutter" -Recurse -Force
   ```

2. **Создайте символическую ссылку:**
   ```powershell
   # В PowerShell от администратора
   New-Item -ItemType SymbolicLink -Path "C:\flutter" -Target "C:\flutter_new\flutter"
   ```

3. **Перезапустите Android Studio**

## Проверка результата

После настройки:
- ✅ `flutter --version` показывает 3.35.2
- ✅ `flutter pub get` работает без ошибок
- ✅ Android Studio использует новую версию Flutter
- ✅ Проект собирается без ошибок доступа к файлам

## Примечания

- Новая версия Flutter установлена в `C:\flutter_new\flutter`
- PowerShell профиль уже обновлен автоматически
- Для постоянной работы обновите системную переменную PATH




