@echo off
echo Installing Flutter dependencies for Evil Crow RF v2 Mobile App...
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter from https://flutter.dev/docs/get-started/install/windows
    echo.
    pause
    exit /b 1
)

echo Flutter found. Installing dependencies...
echo.

REM Install dependencies
flutter pub get

if %errorlevel% equ 0 (
    echo.
    echo Dependencies installed successfully!
    echo.
    echo To run the app:
    echo 1. Connect your Android device or start an emulator
    echo 2. Run: flutter run
    echo.
) else (
    echo.
    echo ERROR: Failed to install dependencies
    echo.
)

pause

