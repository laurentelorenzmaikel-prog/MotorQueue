@echo off
echo ========================================
echo Building Lorenz MotoQ APK
echo ========================================
echo.

echo Step 1: Setting JAVA_HOME to JDK-17...
set "JAVA_HOME=C:\Program Files\Java\jdk-17"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo Verifying Java version...
java -version
echo.

echo Step 2: Cleaning previous build...
flutter clean
echo.

echo Step 3: Getting dependencies...
flutter pub get
echo.

echo Step 4: Building release APK...
flutter build apk --release
echo.

if %ERRORLEVEL% EQU 0 (
    echo ========================================
    echo BUILD SUCCESS!
    echo ========================================
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
) else (
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    echo Error code: %ERRORLEVEL%
    echo.
)

pause
