param (
    [string]$TestTarget = "integration_test/suite_test.dart",
    [string]$DeviceModel = "redfin",
    [string]$DeviceVersion = "30"
)

# Set JAVA_HOME if not set or invalid, assuming Android Studio standard path
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    $PotentialJavaHome = "C:\Program Files\Android\Android Studio\jbr"
    if (Test-Path $PotentialJavaHome) {
        $env:JAVA_HOME = $PotentialJavaHome
        Write-Host "Setting JAVA_HOME to $PotentialJavaHome"
    }
    else {
        Write-Warning "JAVA_HOME is not set and could not find Android Studio JBR."
    }
}

Write-Host "=================================================="
Write-Host "Preparing to run $TestTarget on Firebase Test Lab"
Write-Host "Device: $DeviceModel (API $DeviceVersion)"
Write-Host "=================================================="

# 1. Build Android Test APK
Write-Host "Building Android Test APK..."
Push-Location android
.\gradlew.bat app:assembleAndroidTest
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to build Android Test APK"; exit 1 }
Pop-Location

# 2. Build App APK
Write-Host "Building App APK for target: $TestTarget..."
flutter build apk --debug --target="$TestTarget"
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to build App APK"; exit 1 }

$AppApk = "build/app/outputs/flutter-apk/app-debug.apk"
$TestApk = "build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

if (-not (Test-Path $AppApk)) { Write-Error "App APK not found at $AppApk"; exit 1 }
if (-not (Test-Path $TestApk)) {
    # Fallback check
    $TestApkAlt = "android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
    if (Test-Path $TestApkAlt) {
        $TestApk = $TestApkAlt
    }
    else {
        Write-Error "Test APK not found at $TestApk"; exit 1
    }
}

# 3. Submit to Firebase Test Lab
Write-Host "Submitting to Firebase Test Lab..."
# Note: gcloud needs to be in PATH
gcloud firebase test android run `
    --type instrumentation `
    --app "$AppApk" `
    --test "$TestApk" `
    --device "model=$DeviceModel,version=$DeviceVersion,locale=en,orientation=portrait" `
    --timeout 10m `
    --no-use-orchestrator

Write-Host "Done."
