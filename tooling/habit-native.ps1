param([string]$Device='emulator-5570')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$avd=((& adb -s $Device shell getprop ro.boot.qemu.avd_name) -join '').Trim()
if ($avd -ne 'HandyHabit_QA_API35') { throw 'Dedicated Handy Habit QA emulator required.' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
. (Join-Path $PSScriptRoot 'habit-driver-recovery.ps1')
$mutex=Enter-HandyAndroidBuild
try {
  $before=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app habit).Trim()
  Push-Location (Join-Path $root 'apps/handy_habit')
  try {
    $ErrorActionPreference='Continue'
    & flutter drive --keep-app-running --no-dds --no-start-paused --timeout=240 --driver=test_driver/screenshots.dart --target=integration_test/native_test.dart -d $Device *> (Join-Path $root 'docs/qa/evidence/habit-native.log')
    $code=$LASTEXITCODE
    $ErrorActionPreference='Stop'
  } finally { Pop-Location }
  $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app habit).Trim()
  $transportCode=$code
  $code=Complete-HandyHabitDriver -Name native -Log (Join-Path $root 'docs/qa/evidence/habit-native.log') -Code $code -Source $before -Device $Device
  [pscustomobject]@{app='habit';exitCode=$code;originalTransportExitCode=$transportCode;sourceSha256=$before;sourceUnchanged=($before -eq $after);device=$Device;avd=$avd;physicalDevice=$false} | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/habit-native-result.json') -Encoding utf8
  if ($code -ne 0 -or $before -ne $after) { exit 1 }
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
