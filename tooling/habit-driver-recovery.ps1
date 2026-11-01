# A failed transport is never converted to success from log text. Reconnect the
# original, still-running test process and require a genuine driver response.
function Complete-HandyHabitDriver {
  param([string]$Name,[string]$Log,[int]$Code,[string]$Source,[string]$Device)
  if ($Code -eq 0) { return 0 }
  $root=Split-Path -Parent $PSScriptRoot
  $body=Get-Content -LiteralPath $Log -Raw
  if ($body -notmatch 'Service connection disposed|VMServiceFlutterDriver') { return $Code }
  $namePrefix=if($Name -eq 'native'){'habit'}else{"habit-$Name"}
  Copy-Item -LiteralPath $Log -Destination (Join-Path $root "docs/qa/evidence/$namePrefix-android-screenshots.log") -Force
  $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app habit).Trim()
  [pscustomobject]@{app='habit';exitCode=$Code;sourceSha256=$Source;sourceUnchanged=($Source -eq $after);device=$Device;physicalDevice=$false} | ConvertTo-Json | Set-Content (Join-Path $root "docs/qa/evidence/$namePrefix-android-screenshots-result.json") -Encoding utf8
  # ADB can transiently remove just this emulator's transport. Wait for its
  # original process, without restarting the server or touching other devices.
  $previousErrors=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  for ($attempt=0; $attempt -lt 30; $attempt++) {
    $originalProcess=((& adb -s $Device shell pidof com.example.handysuite.habit.flutterpilot 2>$null) -join '').Trim()
    if ($originalProcess -match '^\d+$') { break }
    Start-Sleep -Milliseconds 500
  }
  $ErrorActionPreference=$previousErrors
  for ($reconnect=0; $reconnect -lt 3; $reconnect++) {
   try {
    & (Join-Path $PSScriptRoot 'flutter-reconnect-driver.ps1') -App habit -Scenario $Name -Device $Device | Out-Null
    $result=Get-Content -LiteralPath (Join-Path $root "docs/qa/evidence/$namePrefix-driver-reconnect-result.json") -Raw | ConvertFrom-Json
    if ($result.exitCode -eq 0 -and $result.sourceSha256 -eq $Source -and $result.existingProcessResultsRetrieved) { return 0 }
   } catch { Write-Warning "Original test driver could not be recovered: $($_.Exception.Message)" }
   Start-Sleep -Milliseconds 1000
  }
  return $Code
}
