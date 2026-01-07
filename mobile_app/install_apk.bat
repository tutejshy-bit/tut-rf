@echo off
echo Installing APK to Android device...
echo.

REM Try to find ADB in common locations
set ADB_PATH=

REM Check if adb is in PATH
where adb >nul 2>&1
if %errorlevel% equ 0 (
    set ADB_PATH=adb
    goto :found
)

REM Check Android SDK common locations
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set ADB_PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
    goto :found
)

if exist "%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
    set ADB_PATH=%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe
    goto :found
)

if exist "C:\Users\%USERNAME%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
    set ADB_PATH=C:\Users\%USERNAME%\AppData\Local\Android\Sdk\platform-tools\adb.exe
    goto :found
)

REM Check if ANDROID_HOME is set
if defined ANDROID_HOME (
    if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
        set ADB_PATH=%ANDROID_HOME%\platform-tools\adb.exe
        goto :found
    )
)

REM Try Flutter's bundled adb
if exist "%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_tools*\cache\artifacts\engine\android-arm\adb.exe" (
    for /f "delims=" %%i in ('dir /s /b "%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_tools*\cache\artifacts\engine\android-arm\adb.exe" 2^>nul') do (
        set ADB_PATH=%%i
        goto :found
    )
)

echo ERROR: ADB not found!
echo.
echo Please install Android SDK Platform Tools or add adb to PATH.
echo You can download it from: https://developer.android.com/studio/releases/platform-tools
echo.
echo Or set ANDROID_HOME environment variable pointing to your Android SDK.
pause
exit /b 1

:found
echo Found ADB at: %ADB_PATH%
echo.

REM Check if device is connected
%ADB_PATH% devices
echo.

REM Check if APK exists
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
if not exist "%APK_PATH%" (
    echo ERROR: APK not found at %APK_PATH%
    echo.
    echo Please build the app first:
    echo   build_production.bat
    echo   or
    echo   flutter build apk --release
    pause
    exit /b 1
)

echo Installing APK...
%ADB_PATH% install -r "%APK_PATH%"

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo APK installed successfully!
    echo ========================================
) else (
    echo.
    echo ERROR: Installation failed!
    echo.
    echo Common issues:
    echo - Device not connected or not authorized
    echo - USB debugging not enabled
    echo - Previous installation conflict (try: adb uninstall com.example.evilcrow_rf2_controller)
    pause
    exit /b %errorlevel%
)

pause

