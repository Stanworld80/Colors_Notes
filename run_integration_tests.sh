#!/bin/bash

# run_integration_tests.sh
# Script to run Flutter integration tests on Android

echo "======================================"
echo "   Running Android Integration Tests"
echo "======================================"

# 1. Check for connected devices
echo "Checking for connected devices..."
flutter devices

# 2. List available emulators (optional information)
echo ""
echo "Available Emulators:"
flutter emulators

# 3. Prompt user (simple) or just run on the first available android device
DEVICE_ID=""
# You could add logic here to parse output or take an argument.
# For now, we rely on flutter's default device selection or user passing -d

echo ""
echo "Starting tests..."
# Run all files ending in _test.dart in the integration_test folder
# Note: sequential execution. For parallel, one needs more setup.
for test_file in integration_test/*_test.dart; do
    echo "Running $test_file..."
    flutter test "$test_file"
    if [ $? -ne 0 ]; then
        echo "❌ Test $test_file Failed!"
        exit 1
    fi
done

echo "✅ All Tests Passed!"
