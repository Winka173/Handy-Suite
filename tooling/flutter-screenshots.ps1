param([ValidateSet('tools','docs','media','dev','keep','recall','save','spend')][string]$App,[ValidateSet('native','pdf','capture','guide','recovery','conversion','camera-share','large-project','state','reader','parity','video-transform','editor')][string]$Scenario='native',[ValidateSet('emulator-5556','emulator-5558')][string]$Device='emulator-5556')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$mutex=Enter-HandyAndroidBuild
$evidenceName=if($Scenario -eq 'native'){$App}else{"$App-$Scenario"}
$log=Join-Path $root "docs/qa/evidence/$evidenceName-android-screenshots.log"
$target=if($App -eq 'tools'){'integration_test/pilot_native_test.dart'}else{'integration_test/native_test.dart'}
if($Scenario -eq 'pdf') {
  if($App -ne 'docs'){throw 'PDF integration is implemented in Docs'}
  $target='integration_test/pdf_native_test.dart'
}
if($Scenario -eq 'reader') {
  if($App -ne 'docs'){throw 'Reader integration is hosted in Docs'}
  $target='integration_test/reader_native_test.dart'
}
if($Scenario -eq 'capture') {
  if($App -ne 'media'){throw 'Capture integration is implemented in Media'}
  $target='integration_test/capture_native_test.dart'
}
if($Scenario -eq 'guide') {
  if($App -ne 'media'){throw 'Guide integration is implemented in Media'}
  $target='integration_test/guide_native_test.dart'
}
if($Scenario -eq 'recovery') {
  if($App -ne 'keep'){throw 'Shared recovery integration is hosted in Keep'}
  $target='integration_test/recovery_native_test.dart'
}
if($Scenario -eq 'conversion') {
  if($App -ne 'media'){throw 'Conversion integration is hosted in Media'}
  $target='integration_test/conversion_native_test.dart'
}
if($Scenario -eq 'camera-share') {
  if($App -ne 'media'){throw 'Camera/share integration is hosted in Media'}
  $target='integration_test/camera_share_native_test.dart'
}
if($Scenario -eq 'large-project') {
  if($App -ne 'media'){throw 'Large project integration is hosted in Media'}
  $target='integration_test/large_project_native_test.dart'
}
if($Scenario -eq 'state') {
  if($App -notin @('tools','dev')){throw 'State integration is hosted in Tools/Dev'}
  $target='integration_test/state_native_test.dart'
}
if($Scenario -eq 'parity') {
  if($App -notin @('docs','media')){throw 'Parity integration is hosted in Docs/Media'}
  $target='integration_test/parity_native_test.dart'
}
if($Scenario -eq 'editor') {
  if($App -ne 'media'){throw 'Editor integration is hosted in Media'}
  $target='integration_test/editor_native_test.dart'
}
if($Scenario -eq 'video-transform') {
  if($App -ne 'media'){throw 'Video transform integration is hosted in Media'}
  $target='integration_test/video_transform_native_test.dart'
}
Push-Location (Join-Path $root "apps/handy_$App")
try {
  $sourceBefore=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
  $ErrorActionPreference='Continue'
  # Regenerate debug-only plugin registration after any release build.
  & flutter drive --no-dds --driver=test_driver/screenshots.dart "--target=$target" -d $Device --dart-define=HANDY_SCREENSHOTS=true *> $log
  $result=$LASTEXITCODE
  $ErrorActionPreference='Stop'
  $sourceAfter=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
  [pscustomobject]@{app=$App;scenario=$Scenario;exitCode=$result;device=$Device;sourceSha256=$sourceBefore;sourceUnchanged=($sourceBefore -eq $sourceAfter);physicalDevice=$false;finishedAt=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root "docs/qa/evidence/$evidenceName-android-screenshots-result.json") -Encoding utf8
  exit $result
} finally { Pop-Location; $mutex.ReleaseMutex(); $mutex.Dispose() }
