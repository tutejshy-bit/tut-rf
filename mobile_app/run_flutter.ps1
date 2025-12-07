# Скрипт для запуска Flutter с правильными переменными окружения
Write-Host "Настройка переменных окружения..." -ForegroundColor Green

# Устанавливаем переменные окружения для текущего процесса и дочерних
$env:PATH = "C:\Program Files\Git\cmd;C:\flutter\bin;" + $env:PATH

# Проверяем Git
Write-Host "Проверка Git..." -ForegroundColor Yellow
try {
    $gitVersion = git --version
    Write-Host "Git найден: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "Ошибка при проверке Git: $_" -ForegroundColor Red
    exit 1
}

# Проверяем Flutter
Write-Host "Проверка Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version
    Write-Host "Flutter найден!" -ForegroundColor Green
    Write-Host $flutterVersion -ForegroundColor Cyan
} catch {
    Write-Host "Ошибка при проверке Flutter: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Все готово! Теперь можно использовать Flutter." -ForegroundColor Green
Write-Host "Для выхода нажмите любую клавишу..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")




