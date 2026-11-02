param(
  [Parameter(Mandatory=$true)][ValidateSet('tools','docs','media','dev','keep','recall','bookmark','spend','habit','trip','boards','card')][string]$App,
  [Parameter(Mandatory=$true)][string]$Scenario,
  [ValidateSet('emulator-5556','emulator-5558','emulator-5570')][string]$Device='emulator-5558'
)
$ErrorActionPreference='Stop'
$fingerprintArgs=if($App -in @('habit','trip','boards','card')){@('--app',$App)}else{@()}
$root=Split-Path -Parent $PSScriptRoot
if ($Scenario -notmatch '^[a-z-]+$') { throw 'Invalid integration scenario' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$mutex=Enter-HandyAndroidBuild
$name=if($Scenario -eq 'native'){$App}else{"$App-$Scenario"}
$evidence=Join-Path $root 'docs/qa/evidence'
$log=Join-Path $evidence "$name-driver-reconnect.log"
$oldServiceUrl=$env:VM_SERVICE_URL
$forwardPort=$null
try {
  $original=Get-Content -LiteralPath (Join-Path $evidence "$name-android-screenshots-result.json") -Raw -Encoding utf8 | ConvertFrom-Json
  $originalLog=Get-Content -LiteralPath (Join-Path $evidence "$name-android-screenshots.log") -Raw
  $sourceHash=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') @fingerprintArgs).Trim()
  if($original.sourceSha256 -and ($original.sourceSha256 -ne $sourceHash -or !$original.sourceUnchanged)) {
    throw 'Source changed since this test launch. Run a fresh integration instead of relabeling old results.'
  }
  if($original.exitCode -eq 0 -or $original.device -ne $Device -or $originalLog -notmatch 'VMServiceFlutterDriver|VM service|Service connection disposed') {
    throw 'Reconnect requires a failed VM transport run on this device. The real driver must still verify the app test result.'
  }
  $package=if($App -eq 'boards'){"com.example.handysuite.handy_boards.flutterpilot"}else{"com.example.handysuite.$App.flutterpilot"}
  $appPid=(& adb -s $Device shell pidof $package).Trim()
  if($LASTEXITCODE -ne 0 -or $appPid -notmatch '^\d+$') { throw 'Original test process is no longer available. Run the test again.' }
  $deviceLog=(& adb -s $Device logcat -d "--pid=$appPid" -s 'flutter:I') -join "`n"
  $matches=[regex]::Matches($deviceLog,'The Dart VM service is listening on http://127\.0\.0\.1:(\d+)/([A-Za-z0-9_=-]+)/')
  if($matches.Count -ne 1) { throw 'Cannot identify the original test VM unambiguously.' }
  $vm=$matches[0]
  $forwardPort=(& adb -s $Device forward tcp:0 "tcp:$($vm.Groups[1].Value)").Trim()
  if($LASTEXITCODE -ne 0 -or $forwardPort -notmatch '^\d+$') { throw 'Could not forward the original VM service.' }
  $env:VM_SERVICE_URL="http://127.0.0.1:$forwardPort/$($vm.Groups[2].Value)/"
  Push-Location (Join-Path $root "apps/handy_$App")
  try {
    $ErrorActionPreference='Continue'
    & dart test_driver/screenshots.dart *> $log
    $result=$LASTEXITCODE
    $ErrorActionPreference='Stop'
  } finally { Pop-Location }
  if($result -ne 0 -or (Get-Content -LiteralPath $log -Raw) -notmatch 'All tests passed\.') {
    throw 'Driver did not retrieve a successful test response. Original failure is preserved.'
  }
  [pscustomobject]@{
    app=$App;scenario=$Scenario;device=$Device;physicalDevice=$false;exitCode=$result
    originalTransportExitCode=$original.exitCode;originalTestProcess=[int]$appPid
    sourceSha256=$sourceHash
    logSha256=(Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant()
    existingProcessResultsRetrieved=$true;finishedAt=(Get-Date).ToUniversalTime().ToString('o')
    appTestsAlreadyFinishedBeforeReconnect=($originalLog -match 'All tests passed!')
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence "$name-driver-reconnect-result.json") -Encoding utf8
} finally {
  $env:VM_SERVICE_URL=$oldServiceUrl
  if($forwardPort -match '^\d+$') { & adb -s $Device forward --remove "tcp:$forwardPort" | Out-Null }
  $mutex.ReleaseMutex(); $mutex.Dispose()
}
