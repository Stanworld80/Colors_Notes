---
description: Automated Notification Testing Workflow
---

# Automated Notification Testing

This workflow describes how to run the dedicated notification integration tests on Firebase Test Lab.

## Prerequisites

- Active Google Cloud Project with Firebase Test Lab enabled.
- `gcloud` CLI installed and authenticated.
- Android Studio / Java configured (handled by script).

## Running the Test

To run the notification flow test specifically (skipping other tests for speed):

```powershell
./tools/run_firebase_notification_test.ps1
```

## Customization

You can specify device models and API levels:

```powershell
./tools/run_firebase_notification_test.ps1 -DeviceModel "Pixel6" -DeviceVersion "33"
```

## What it tests

1. User registration/login (smoke).
2. Creating and editing a journal.
3. Enabling notifications (permission checks).
4. Triggering "Immediate" test notification.
5. Scheduling "In 10s" test notification.
6. Verifying "Fix Battery Restrictions" UI interaction.

## Results

Results will be available in the Firebase Console link provided by the script output.
