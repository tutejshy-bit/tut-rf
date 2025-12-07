# Скрипт для обновления PowerShell профиля с новым Flutter
Write-Host "Обновление PowerShell профиля для нового Flutter..." -ForegroundColor Green

# Проверяем, существует ли профиль
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath -Parent

# Создаем директорию профиля, если она не существует
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Host "Создана директория профиля: $profileDir" -ForegroundColor Yellow
}

# Содержимое профиля с новым путем к Flutter
$profileContent = @"
# Flutter и Git настройки (обновленная версия)
`$env:PATH = "C:\flutter_new\flutter\bin\mingit\cmd;C:\flutter_new\flutter\bin;" + `$env:PATH

# Проверяем, что Flutter доступен
try {
    flutter --version | Out-Null
    Write-Host "Flutter 3.35.2 готов к использованию!" -ForegroundColor Green
} catch {
    Write-Host "Flutter не найден. Проверьте установку." -ForegroundColor Red
}
"@

# Записываем профиль
$profileContent | Out-File -FilePath $profilePath -Encoding UTF8
Write-Host "Профиль обновлен: $profilePath" -ForegroundColor Green

# Перезагружаем профиль
Write-Host "Перезагрузка профиля..." -ForegroundColor Yellow
. $profilePath

Write-Host "Обновление профиля завершено!" -ForegroundColor Green
Write-Host "Теперь используется Flutter 3.35.2 в папке C:\flutter_new\flutter" -ForegroundColor Cyan




