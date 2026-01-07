@echo off
echo Building Flutter app in RELEASE mode...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo ERROR: Build failed!
    exit /b %errorlevel%
)
echo.
echo Build completed successfully!
echo APK location: build\app\outputs\flutter-apk\app-release.apk
echo.

