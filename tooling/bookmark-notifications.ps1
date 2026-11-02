param([string]$Device='emulator-5558')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if ((& adb -s $Device emu avd name) -notcontains 'HandySave_QA_API35') { throw 'Dedicated Handy Bookmark QA emulator required' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$mutex=Enter-HandyAndroidBuild
$records=@()
Push-Location (Join-Path $root 'apps/handy_bookmark')
try {
  foreach($granted in @($false,$true)) {
    $source=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
    # flutter drive may uninstall its test app on exit. Install the preserved
    # main entrypoint before setting each permission state.
    & adb -s $Device install -r (Join-Path $root 'artifacts/flutter/handy_bookmark/android/handy-save-pilot-debug.apk')
    if($LASTEXITCODE -ne 0){throw 'Could not install QA app'}
    $verb=if($granted){'grant'}else{'revoke'}
    & adb -s $Device shell pm $verb com.example.handysuite.save.flutterpilot android.permission.POST_NOTIFICATIONS
    if($LASTEXITCODE -ne 0){throw 'Could not set QA permission'}
    $label=if($granted){'granted'}else{'denied'}
    $log=Join-Path $root "docs/qa/evidence/save-notifications-$label.log"
    $ErrorActionPreference='Continue'
    & flutter drive --no-dds --driver=test_driver/screenshots.dart --target=integration_test/notifications_test.dart -d $Device "--dart-define=EXPECTED_NOTIFICATIONS=$($granted.ToString().ToLowerInvariant())" *> $log
    $code=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
    $records += [pscustomobject]@{permission=$granted;exitCode=$code;sourceSha256=$source;sourceUnchanged=($source -eq $after);device=$Device;physicalDevice=$false}
  }
  $records | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/save-notifications-results.json') -Encoding utf8
  if($records.Where({$_.exitCode -ne 0 -or !$_.sourceUnchanged}).Count){exit 1}
} finally { Pop-Location; $mutex.ReleaseMutex(); $mutex.Dispose() }
