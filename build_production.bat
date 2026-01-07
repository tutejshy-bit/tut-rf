@echo off
echo ========================================
echo Building Production Firmware and App
echo ========================================
echo.

REM Build ESP32 firmware in production mode
echo [1/2] Building ESP32 firmware (production)...
python -m platformio run -e esp32dev
if %errorlevel% neq 0 (
    echo ERROR: Firmware build failed!
    exit /b %errorlevel%
)
echo Firmware build completed successfully!
echo.

REM Build Flutter app in release mode
echo [2/2] Building Flutter app (release)...
cd mobile_app
call flutter build apk --release
if %errorlevel% neq 0 (
    echo ERROR: Flutter app build failed!
    cd ..
    exit /b %errorlevel%
)
cd ..
echo.

echo ========================================
echo Production build completed successfully!
echo ========================================
echo Firmware: .pio\build\esp32dev\firmware.bin
echo App: mobile_app\build\app\outputs\flutter-apk\app-release.apk
echo.
echo To install APK on Android device:
echo   cd mobile_app
echo   install_apk.bat
echo.

