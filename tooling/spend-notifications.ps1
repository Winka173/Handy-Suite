param([string]$Device='emulator-5558')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$avdIdentity=((& adb -s $Device shell getprop ro.boot.qemu.avd_name) -join '').Trim()
if ($avdIdentity -ne 'HandySpend_QA_API35') { throw 'Dedicated Spend QA emulator required' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$mutex=Enter-HandyAndroidBuild
$records=@()
Push-Location (Join-Path $root 'apps/handy_spend')
try {
 foreach($granted in @($false,$true)) {
  $source=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
  & adb -s $Device install -r (Join-Path $root 'artifacts/flutter/handy_spend/android/handy-spend-pilot-debug.apk')
  if($LASTEXITCODE -ne 0){throw 'Could not install QA app'}
  $verb=if($granted){'grant'}else{'revoke'}
  & adb -s $Device shell pm $verb com.example.handysuite.spend.flutterpilot android.permission.POST_NOTIFICATIONS
  if($LASTEXITCODE -ne 0){throw 'Could not set QA permission'}
  $label=if($granted){'granted'}else{'denied'}
  $ErrorActionPreference='Continue'
  & flutter drive --no-dds --no-start-paused --timeout=240 --driver=test_driver/screenshots.dart --target=integration_test/notifications_test.dart -d $Device "--dart-define=EXPECTED_NOTIFICATIONS=$($granted.ToString().ToLowerInvariant())" *> (Join-Path $root "docs/qa/evidence/spend-notifications-$label.log")
  $code=$LASTEXITCODE
  $ErrorActionPreference='Stop'
  $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
  $records += [pscustomobject]@{permission=$granted;exitCode=$code;sourceSha256=$source;sourceUnchanged=($source -eq $after);device=$Device;physicalDevice=$false}
 }
 $records | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/spend-notifications-results.json') -Encoding utf8
 if($records.Where({$_.exitCode -ne 0 -or !$_.sourceUnchanged}).Count){exit 1}
} finally { Pop-Location; $mutex.ReleaseMutex(); $mutex.Dispose() }
