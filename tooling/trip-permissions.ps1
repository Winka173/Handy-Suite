param([string]$Device='emulator-5570')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (((& adb -s $Device shell getprop ro.boot.qemu.avd_name) -join '').Trim() -ne 'HandyTrip_QA_API35') { throw 'Dedicated Trip QA emulator required' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$tripPermissionMutex=Enter-HandyAndroidBuild
$tripPickerJob=$null
try {
  foreach($permission in @('ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION','POST_NOTIFICATIONS')) {
    & adb -s $Device shell pm revoke com.example.handysuite.trip.flutterpilot "android.permission.$permission" | Out-Null
    & adb -s $Device shell pm set-permission-flags com.example.handysuite.trip.flutterpilot "android.permission.$permission" user-set user-fixed | Out-Null
  }
  $tripPickerJob=Start-Job -ArgumentList $Device -ScriptBlock {
    param($serial)
    $deadline=(Get-Date).AddMinutes(4)
    while((Get-Date) -lt $deadline) {
      $focus=((& adb -s $serial shell dumpsys window 2>$null) -join "`n")
      if($focus -match '(?m)mCurrentFocus=.+(PhotoPicker|photopicker|PickImages)') {
        & adb -s $serial shell input keyevent KEYCODE_BACK | Out-Null
        return 'Actual Android photo picker cancelled by Back'
      }
      Start-Sleep -Milliseconds 500
    }
    throw 'Actual Android photo picker never appeared'
  }
  & (Join-Path $PSScriptRoot 'trip-native.ps1') -Device $Device -Scenario permissions
  $tripPermissionCode=$LASTEXITCODE
  if($tripPermissionCode -eq 0) {
    Receive-Job -Job $tripPickerJob -Wait | Set-Content (Join-Path $root 'docs/qa/evidence/trip-picker-cancel.log') -Encoding utf8
  }
  if($tripPermissionCode -ne 0){exit $tripPermissionCode}
} finally {
  if($tripPickerJob) {if($tripPickerJob.State -eq 'Running'){Stop-Job -Job $tripPickerJob};Remove-Job -Job $tripPickerJob}
  foreach($permission in @('ACCESS_COARSE_LOCATION','ACCESS_FINE_LOCATION','POST_NOTIFICATIONS')) {
    & adb -s $Device shell pm clear-permission-flags com.example.handysuite.trip.flutterpilot "android.permission.$permission" user-set user-fixed | Out-Null
    & adb -s $Device shell pm grant com.example.handysuite.trip.flutterpilot "android.permission.$permission" | Out-Null
  }
  $tripPermissionMutex.ReleaseMutex();$tripPermissionMutex.Dispose()
}
