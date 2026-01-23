# Current Context & Status (Step 164)

## Objective
Run functional tests (`notification_flow_test.dart`) to determine app health and notification functionality.

## Progress
1. Identified issues with the previous emulator (API 36/Preview?) and stale environment.
2. Located correct `JAVA_HOME` at `C:\Program Files\Android\Android Studio\jbr`.
3. Installed `system-images;android-34;google_apis;x86_64` (Android 14) via `sdkmanager`.
4. Created a new AVD `Pixel_Test_API34`.
5. Killed old emulator and launched the new one (`emulator-5554`).
6. Started `flutter test integration_test/notification_flow_test.dart`.

## Current State
- Test is running (building `assembleDebug`).
- Waiting for completion.

## Potential Risks
- `Firebase.initializeApp` might fail if called multiple times or configured incorrectly.
- `firebase_core` 4.2.1 is used.
- Permissions for notifications on API 34 require explicit grant (handled in code).

## Next Actions
- Monitor test output.
- If failure persists (Firebase init), investigate `bootstrap.dart` vs `integration_test` lifecycle.
