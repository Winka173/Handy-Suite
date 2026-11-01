param([string]$Device='emulator-5570')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$avdIdentity=((& adb -s $Device shell getprop ro.boot.qemu.avd_name) -join '').Trim()
if ($avdIdentity -ne 'HandyHabit_QA_API35') { throw 'Dedicated Habit QA emulator required' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
. (Join-Path $PSScriptRoot 'habit-driver-recovery.ps1')
$mutex=Enter-HandyAndroidBuild
$records=@()
Push-Location (Join-Path $root 'apps/handy_habit')
try {
 foreach($granted in @($false,$true)) {
  $source=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app habit).Trim()
  & adb -s $Device install -r (Join-Path $root 'artifacts/flutter/handy_habit/android/handy-habit-pilot-debug.apk')
  if($LASTEXITCODE -ne 0){throw 'Could not install QA app'}
  $verb=if($granted){'grant'}else{'revoke'}
  & adb -s $Device shell pm $verb com.example.handysuite.habit.flutterpilot android.permission.POST_NOTIFICATIONS
  if($LASTEXITCODE -ne 0){throw 'Could not set QA permission'}
  if ($granted) {
    & adb -s $Device shell pm clear-permission-flags com.example.handysuite.habit.flutterpilot android.permission.POST_NOTIFICATIONS user-set user-fixed
  } else {
    & adb -s $Device shell pm set-permission-flags com.example.handysuite.habit.flutterpilot android.permission.POST_NOTIFICATIONS user-fixed
  }
  if($LASTEXITCODE -ne 0){throw 'Could not set dedicated QA permission flags'}
  $label=if($granted){'granted'}else{'denied'}
  $ErrorActionPreference='Continue'
  & flutter drive --keep-app-running --no-dds --no-start-paused --timeout=240 --driver=test_driver/screenshots.dart --target=integration_test/notifications_test.dart -d $Device "--dart-define=EXPECTED_NOTIFICATIONS=$($granted.ToString().ToLowerInvariant())" *> (Join-Path $root "docs/qa/evidence/habit-notifications-$label.log")
  $code=$LASTEXITCODE
  $ErrorActionPreference='Stop'
  $transportCode=$code
  $code=Complete-HandyHabitDriver -Name "notifications-$label" -Log (Join-Path $root "docs/qa/evidence/habit-notifications-$label.log") -Code $code -Source $source -Device $Device
  $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app habit).Trim()
  $records += [pscustomobject]@{permission=$granted;exitCode=$code;originalTransportExitCode=$transportCode;sourceSha256=$source;sourceUnchanged=($source -eq $after);device=$Device;physicalDevice=$false}
 }
 $records | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/habit-notifications-results.json') -Encoding utf8
 if($records.Where({$_.exitCode -ne 0 -or !$_.sourceUnchanged}).Count){exit 1}
} finally { Pop-Location; $mutex.ReleaseMutex(); $mutex.Dispose() }
