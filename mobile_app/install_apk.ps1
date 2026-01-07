# Install APK to Android device
Write-Host "Installing APK to Android device..." -ForegroundColor Cyan
Write-Host ""

# Try to find ADB
$adbPath = $null

# Check if adb is in PATH
try {
    $null = Get-Command adb -ErrorAction Stop
    $adbPath = "adb"
    Write-Host "Found ADB in PATH" -ForegroundColor Green
} catch {
    # Check common Android SDK locations
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    )
    
    # Check ANDROID_HOME
    if ($env:ANDROID_HOME) {
        $possiblePaths += "$env:ANDROID_HOME\platform-tools\adb.exe"
    }
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $adbPath = $path
            Write-Host "Found ADB at: $path" -ForegroundColor Green
            break
        }
    }
}

if (-not $adbPath) {
    Write-Host "ERROR: ADB not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Android SDK Platform Tools or add adb to PATH." -ForegroundColor Yellow
    Write-Host "Download from: https://developer.android.com/studio/releases/platform-tools" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or set ANDROID_HOME environment variable pointing to your Android SDK." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Check if device is connected
Write-Host "Checking connected devices..." -ForegroundColor Yellow
& $adbPath devices
Write-Host ""

# Check if APK exists
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "ERROR: APK not found at $apkPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please build the app first:" -ForegroundColor Yellow
    Write-Host "  build_production.bat" -ForegroundColor Cyan
    Write-Host "  or" -ForegroundColor Cyan
    Write-Host "  flutter build apk --release" -ForegroundColor Cyan
    exit 1
}

Write-Host "Installing APK..." -ForegroundColor Yellow
& $adbPath install -r $apkPath

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "APK installed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "ERROR: Installation failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "- Device not connected or not authorized" -ForegroundColor Yellow
    Write-Host "- USB debugging not enabled" -ForegroundColor Yellow
    Write-Host "- Previous installation conflict (try: adb uninstall com.example.evilcrow_rf2_controller)" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

