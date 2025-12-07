# Решение проблемы "Unable to find git in your PATH" для Flutter

## Проблема
При попытке запустить Flutter возникает ошибка:
```
Error: Unable to find git in your PATH.
```

## Причина
Flutter требует Git для работы, но не может найти его в системном PATH. Даже если Git установлен в системе, Flutter может не видеть его из-за особенностей настройки переменных окружения.

## Решение

### 1. Автоматическое решение (рекомендуется)
Запустите скрипт установки профиля PowerShell:
```powershell
.\install_flutter_profile.ps1
```

Этот скрипт:
- Устанавливает PowerShell профиль с правильными настройками
- Добавляет пути к Flutter и встроенному Git в PATH
- Автоматически применяется при каждом запуске PowerShell

### 2. Ручное решение
Добавьте следующие пути в переменную PATH:
```
C:\flutter\bin\mingit\cmd
C:\flutter\bin
```

### 3. Быстрый запуск
Используйте bat-файл для быстрого запуска Flutter:
```cmd
.\flutter.bat --version
```

## Проверка
После настройки выполните:
```powershell
flutter --version
flutter doctor
```

## Файлы решения
- `install_flutter_profile.ps1` - установка PowerShell профиля
- `run_flutter.ps1` - временный запуск Flutter
- `run_flutter.bat` - временный запуск Flutter (CMD)
- `flutter.bat` - быстрый запуск Flutter с правильными настройками

## Примечания
- Flutter поставляется со встроенной версией Git в папке `mingit`
- Используйте встроенный Git вместо системного для избежания конфликтов
- PowerShell профиль автоматически настраивается при каждом запуске




