# Скрипт для настройки переменных окружения для Flutter
Write-Host "Настройка переменных окружения для Flutter..." -ForegroundColor Green

# Добавляем пути к Git и Flutter в PATH
$env:PATH = "C:\Program Files\Git\cmd;C:\flutter\bin;" + $env:PATH

# Проверяем Git
Write-Host "Проверка Git..." -ForegroundColor Yellow
try {
    $gitVersion = & "C:\Program Files\Git\cmd\git.exe" --version 2>$null
    if ($gitVersion) {
        Write-Host "Git найден: $gitVersion" -ForegroundColor Green
    } else {
        Write-Host "Git не найден!" -ForegroundColor Red
    }
} catch {
    Write-Host "Ошибка при проверке Git: $_" -ForegroundColor Red
}

# Проверяем Flutter
Write-Host "Проверка Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = & "C:\flutter\bin\flutter.bat" --version 2>$null
    if ($flutterVersion) {
        Write-Host "Flutter найден: $flutterVersion" -ForegroundColor Green
    } else {
        Write-Host "Flutter не найден!" -ForegroundColor Red
    }
} catch {
    Write-Host "Ошибка при проверке Flutter: $_" -ForegroundColor Red
}

Write-Host "Настройка завершена. Теперь вы можете использовать команды git и flutter." -ForegroundColor Green
Write-Host "Для постоянной настройки добавьте эти пути в системные переменные окружения." -ForegroundColor Yellow




