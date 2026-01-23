#!/bin/bash

# run_firebase_test_lab.sh
# Script to build and run Flutter integration tests on Firebase Test Lab

TEST_TARGET=${1:-"integration_test/suite_test.dart"}
DEVICE_MODEL=${2:-"Pixel3"}
DEVICE_VERSION=${3:-"30"}

echo "=================================================="
echo "Preparing to run $TEST_TARGET on Firebase Test Lab"
echo "Device: $DEVICE_MODEL (API $DEVICE_VERSION)"
echo "=================================================="

# 1. Build the Instrumentation Test APK (Runner)
echo "Building Android Test APK..."
cd android
./gradlew app:assembleAndroidTest
if [ $? -ne 0 ]; then
    echo "❌ Failed to build Android Test APK"
    exit 1
fi
cd ..

# 2. Build the App APK with the specific test target
echo "Building App APK for target: $TEST_TARGET..."
flutter build apk --debug --target="$TEST_TARGET"
if [ $? -ne 0 ]; then
    echo "❌ Failed to build App APK"
    exit 1
fi

# Define APK paths
APP_APK="build/app/outputs/flutter-apk/app-debug.apk"
TEST_APK="build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

if [ ! -f "$APP_APK" ]; then
    echo "❌ App APK not found at $APP_APK"
    exit 1
fi

if [ ! -f "$TEST_APK" ]; then
    echo "❌ Test APK not found at $TEST_APK"
    # Fallback to check other possible location if gradle output differs
    TEST_APK_ALT="android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
    if [ -f "$TEST_APK_ALT" ]; then
        TEST_APK="$TEST_APK_ALT"
    else
        exit 1
    fi
fi

# 3. Submit to Firebase Test Lab
echo "Submitting to Firebase Test Lab..."
gcloud firebase test android run \
  --type instrumentation \
  --app "$APP_APK" \
  --test "$TEST_APK" \
  --device model="$DEVICE_MODEL",version="$DEVICE_VERSION",locale=en,orientation=portrait \
  --timeout 10m \
  --use-orchestrator=false

echo "=================================================="
echo "✅ Test Lab run initiated"
echo "=================================================="
