param (
    [switch]$SkipTests,
    [switch]$RunIntegrationTests,
    [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   COLORS & NOTES - LOCAL CI/CD PIPELINE      " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# 1. CLEAN & DEPENDENCIES
Write-Host "`n[1/5] 🧹 Cleaning and getting dependencies..." -ForegroundColor Yellow
flutter clean
flutter pub get

# 2. STATIC ANALYSIS & UNIT TESTS
if (-not $SkipTests) {
    Write-Host "`n[2/5] 🛡️ Running Static Analysis..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) { Write-Error "Linting failed!"; exit 1 }

    Write-Host "`n[3/5] 🧪 Running Unit & Widget Tests..." -ForegroundColor Yellow
    # Run all tests in test/ except integration_test logic which is separate usually
    flutter test test/unit
    if ($LASTEXITCODE -ne 0) { Write-Error "Unit Tests failed!"; exit 1 }
    
    flutter test test/widget
    if ($LASTEXITCODE -ne 0) { Write-Error "Widget Tests failed!"; exit 1 }

    if ($RunIntegrationTests) {
        Write-Host "`n[3.5/5] 🤖 Running Integration Tests (Firebase Test Lab)..." -ForegroundColor Yellow
        # Call the existing script
        & "$PSScriptRoot\run_firebase_notification_test.ps1"
        if ($LASTEXITCODE -ne 0) { Write-Error "Integration Tests failed!"; exit 1 }
    }
}
else {
    Write-Host "`n[2/5] & [3/5] Tests skipped." -ForegroundColor Gray
}

# 3. BUILD RELEASE APK
Write-Host "`n[4/5] 🏗️ Building Release APK..." -ForegroundColor Yellow
# Ensure correct google-services.json for staging/prod is present
# For local run, we assume the environment is set up or prompt user if critical files missing
if (-not (Test-Path "android/app/google-services.json")) {
    Write-Warning "google-services.json missing! Attempting to use staging..."
    if (Test-Path "android/app/google-services.staging.json") {
        Copy-Item "android/app/google-services.staging.json" "android/app/google-services.json" -Force
        Write-Host "Copied staging google-services.json" -ForegroundColor Green
    }
    else {
        Write-Error "No google-services.json found. Build will fail."
    }
}
if (-not (Test-Path "android/key.properties")) {
    Write-Warning "key.properties missing! Attempting to use staging..."
    if (Test-Path "android/key.staging.properties") {
        Copy-Item "android/key.staging.properties" "android/key.properties" -Force
        Write-Host "Copied staging key.properties" -ForegroundColor Green
    }
}

flutter build apk --release --dart-define=APP_ENV=staging
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed!"; exit 1 }

# 4. DEPLOY
if (-not $SkipDeploy) {
    Write-Host "`n[5/5] 🚀 Deploying to Firebase App Distribution..." -ForegroundColor Yellow
    
    $AppId = "1:344541548510:android:631fa078fb9926677d174f" # Staging App ID
    $ApkPath = "build/app/outputs/flutter-apk/app-release.apk"
    $Groups = "uat-testers"
    $ReleaseNotes = "Local CI/CD Build - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

    firebase appdistribution:distribute "$ApkPath" --app "$AppId" --release-notes "$ReleaseNotes" --groups "$Groups"
    if ($LASTEXITCODE -ne 0) { Write-Error "Deployment failed!"; exit 1 }
    
    Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green
}
else {
    Write-Host "`n[5/5] Deployment skipped." -ForegroundColor Gray
}

Write-Host "`n🎉 Pipeline Finished Successfully!" -ForegroundColor Cyan
