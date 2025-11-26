# Lorenz MotoQ APK Build Script
Write-Host "========================================"
Write-Host "Building Lorenz MotoQ APK"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set JAVA_HOME to JDK-17
Write-Host "Step 1: Setting JAVA_HOME to JDK-17..." -ForegroundColor Yellow
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
$env:PATH = "C:\Program Files\Java\jdk-17\bin;" + $env:PATH

# Verify Java version
Write-Host "Verifying Java version..." -ForegroundColor Yellow
java -version
Write-Host ""

# Clean previous build
Write-Host "Step 2: Cleaning previous build..." -ForegroundColor Yellow
flutter clean
Write-Host ""

# Get dependencies
Write-Host "Step 3: Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host ""

# Build release APK
Write-Host "Step 4: Building release APK..." -ForegroundColor Yellow
flutter build apk --release

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "BUILD SUCCESS!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
}

Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
