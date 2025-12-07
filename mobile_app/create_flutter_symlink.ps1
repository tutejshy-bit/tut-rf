# Скрипт для создания символической ссылки на новый Flutter
Write-Host "Создание символической ссылки для Flutter..." -ForegroundColor Green

# Проверяем, существует ли старая папка Flutter
$oldFlutterPath = "C:\flutter"
$newFlutterPath = "C:\flutter_new\flutter"

if (Test-Path $oldFlutterPath) {
    Write-Host "Удаление старой папки Flutter..." -ForegroundColor Yellow
    try {
        Remove-Item $oldFlutterPath -Recurse -Force
        Write-Host "Старая папка Flutter удалена!" -ForegroundColor Green
    } catch {
        Write-Host "Ошибка при удалении старой папки: $_" -ForegroundColor Red
        Write-Host "Попробуйте запустить PowerShell от имени администратора" -ForegroundColor Yellow
        exit 1
    }
}

# Создаем символическую ссылку
Write-Host "Создание символической ссылки..." -ForegroundColor Yellow
try {
    New-Item -ItemType SymbolicLink -Path $oldFlutterPath -Target $newFlutterPath -Force
    Write-Host "Символическая ссылка создана успешно!" -ForegroundColor Green
    Write-Host "C:\flutter → C:\flutter_new\flutter" -ForegroundColor Cyan
} catch {
    Write-Host "Ошибка при создании символической ссылки: $_" -ForegroundColor Red
    Write-Host "Попробуйте запустить PowerShell от имени администратора" -ForegroundColor Yellow
    exit 1
}

# Проверяем, что ссылка работает
Write-Host "Проверка символической ссылки..." -ForegroundColor Yellow
if (Test-Path $oldFlutterPath) {
    $flutterVersion = & "$oldFlutterPath\bin\flutter.bat" --version 2>$null
    if ($flutterVersion) {
        Write-Host "Символическая ссылка работает! Flutter версия:" -ForegroundColor Green
        Write-Host $flutterVersion -ForegroundColor Cyan
    } else {
        Write-Host "Символическая ссылка создана, но Flutter не работает" -ForegroundColor Red
    }
}

Write-Host "Настройка завершена!" -ForegroundColor Green
Write-Host "Теперь Android Studio должен использовать новую версию Flutter" -ForegroundColor Cyan
Write-Host "Перезапустите Android Studio для применения изменений" -ForegroundColor Yellow




