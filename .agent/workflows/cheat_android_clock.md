---
description: How to change the Android Emulator clock for testing alarms
---

To test time-based triggers like scheduled notifications without waiting, you can change the system clock on the Android Emulator using ADB.

**Note:** This works best on local emulators. It may not work on Firebase Test Lab or real devices without root.

1. **Check current time on device:**
   ```powershell
   adb shell date
   ```

2. **Set a specific time:**
   Format: `MMDDhhmm[[CC]YY][.ss]`
   Example: To set date to January 24, 15:30 (3:30 PM) 2026:
   ```powershell
   adb shell date 012415302026.00
   ```

3. **Advance time by X hours/minutes (Manual calculation required):**
   You have to calculate the new time timestamp manually and set it.

4. **Reset to network time (if needed):**
   Usually enabling "Automatic date & time" in settings fixes it, or rebooting the emulator.
   ```powershell
   adb shell settings put global auto_time 1
   ```

**Alternative: "Fast Forward" Testing**
Instead of changing the clock, use the **"Test: Schedule Interval"** button in the app (Edit Journal Page) and set the interval to a small value (e.g., 1 minute) to quickly verify notifications locally.
