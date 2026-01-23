param (
    [string]$DeviceModel = "redfin",
    [string]$DeviceVersion = "30"
)

# Reuse the main script but target the notification flow specifically
& "$PSScriptRoot\run_firebase_test_lab.ps1" -TestTarget "integration_test/notification_flow_test.dart" -DeviceModel $DeviceModel -DeviceVersion $DeviceVersion
