# Скрипт для установки PowerShell профиля с настройками Flutter
Write-Host "Установка PowerShell профиля для Flutter..." -ForegroundColor Green

# Проверяем, существует ли профиль
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath -Parent

# Создаем директорию профиля, если она не существует
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Host "Создана директория профиля: $profileDir" -ForegroundColor Yellow
}

# Содержимое профиля
$profileContent = @"
# Flutter и Git настройки
`$env:PATH = "C:\flutter\bin\mingit\cmd;C:\flutter\bin;" + `$env:PATH

# Проверяем, что Flutter доступен
try {
    flutter --version | Out-Null
    Write-Host "Flutter готов к использованию!" -ForegroundColor Green
} catch {
    Write-Host "Flutter не найден. Проверьте установку." -ForegroundColor Red
}
"@

# Записываем профиль
$profileContent | Out-File -FilePath $profilePath -Encoding UTF8
Write-Host "Профиль установлен: $profilePath" -ForegroundColor Green

# Перезагружаем профиль
Write-Host "Перезагрузка профиля..." -ForegroundColor Yellow
. $profilePath

Write-Host "Установка завершена!" -ForegroundColor Green
Write-Host "Теперь Flutter будет доступен в каждом новом сеансе PowerShell." -ForegroundColor Cyan
Write-Host "Для применения изменений в текущем сеансе выполните: . `$PROFILE" -ForegroundColor Yellow




