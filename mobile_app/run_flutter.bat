@echo off
REM Скрипт для запуска Flutter с правильными переменными окружения
set PATH=C:\Program Files\Git\cmd;C:\flutter\bin;%PATH%

REM Проверяем Git
echo Проверка Git...
git --version
if %ERRORLEVEL% NEQ 0 (
    echo Ошибка: Git не найден!
    pause
    exit /b 1
)

REM Проверяем Flutter
echo Проверка Flutter...
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo Ошибка: Flutter не найден!
    pause
    exit /b 1
)

echo Все готово! Теперь можно использовать Flutter.
pause




