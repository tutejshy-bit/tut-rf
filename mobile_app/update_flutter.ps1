# Скрипт для обновления Flutter
Write-Host "Обновление Flutter..." -ForegroundColor Green

# Создаем временную папку для загрузки
$tempDir = "C:\temp_flutter_update"
$flutterDir = "C:\flutter_new"

if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
if (Test-Path $flutterDir) {
    Remove-Item $flutterDir -Recurse -Force
}

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path $flutterDir -Force | Out-Null

Write-Host "Загрузка Flutter..." -ForegroundColor Yellow

# URL для загрузки Flutter
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.35.2-stable.zip"
$zipPath = Join-Path $tempDir "flutter.zip"

try {
    # Загружаем Flutter
    Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Flutter загружен успешно!" -ForegroundColor Green
    
    # Распаковываем архив
    Write-Host "Распаковка Flutter..." -ForegroundColor Yellow
    Expand-Archive -Path $zipPath -DestinationPath $flutterDir -Force
    
    # Перемещаем содержимое
    $flutterContent = Get-ChildItem $flutterDir -Name | Where-Object { $_ -ne "flutter" }
    if ($flutterContent) {
        Move-Item "$flutterDir\flutter\*" $flutterDir -Force
        Remove-Item "$flutterDir\flutter" -Force
    }
    
    Write-Host "Flutter обновлен до версии 3.35.2!" -ForegroundColor Green
    
    # Обновляем PATH
    $env:PATH = $env:PATH -replace "C:\\flutter\\bin", "$flutterDir\bin"
    $env:PATH = "$flutterDir\bin\mingit\cmd;$flutterDir\bin;" + $env:PATH
    
    Write-Host "PATH обновлен!" -ForegroundColor Green
    
    # Проверяем версию
    Write-Host "Проверка новой версии Flutter..." -ForegroundColor Yellow
    & "$flutterDir\bin\flutter.bat" --version
    
} catch {
    Write-Host "Ошибка при обновлении Flutter: $_" -ForegroundColor Red
} finally {
    # Очищаем временные файлы
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

Write-Host "Обновление завершено!" -ForegroundColor Green
Write-Host "Новый Flutter установлен в: $flutterDir" -ForegroundColor Cyan
Write-Host "Для постоянного использования обновите переменную PATH в системных настройках." -ForegroundColor Yellow




