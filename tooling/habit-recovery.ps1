param([string]$Device='emulator-5570')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (((& adb -s $Device shell getprop ro.boot.qemu.avd_name) -join '').Trim() -ne 'HandyHabit_QA_API35') { throw 'Dedicated Habit emulator required.' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
. (Join-Path $PSScriptRoot 'habit-driver-recovery.ps1')
$mutex=Enter-HandyAndroidBuild
$rows=@()
try {
  $source=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app habit).Trim()
  Push-Location (Join-Path $root 'apps/handy_habit')
  try {
    foreach($reopen in @($false,$true)) {
      if ($reopen) { & adb -s $Device shell am force-stop com.example.handysuite.habit.flutterpilot }
      $label=if($reopen){'reopen'}else{'seed'}
      $log=Join-Path $root "docs/qa/evidence/habit-process-$label.log"
      $ErrorActionPreference='Continue'
      & flutter drive --keep-app-running --no-dds --no-start-paused --timeout=240 --driver=test_driver/screenshots.dart --target=integration_test/recovery_test.dart -d $Device "--dart-define=HABIT_REOPEN=$($reopen.ToString().ToLowerInvariant())" *> $log
      $code=$LASTEXITCODE
      $ErrorActionPreference='Stop'
      $transportCode=$code
      $code=Complete-HandyHabitDriver -Name "process-$label" -Log $log -Code $code -Source $source -Device $Device
      $match=[regex]::Match((Get-Content -LiteralPath $log -Raw),'HABIT_QA_PROCESS=(\d+)')
      $process=if($match.Success){[int]$match.Groups[1].Value}else{$null}
      if ($code -eq 0 -and !$process) {
        $reconnected=Get-Content -LiteralPath (Join-Path $root "docs/qa/evidence/habit-process-$label-driver-reconnect-result.json") -Raw | ConvertFrom-Json
        $process=$reconnected.originalTestProcess
      }
      $rows+=[pscustomobject]@{phase=$label;exitCode=$code;originalTransportExitCode=$transportCode;process=$process}
      if ($code -ne 0) { break }
    }
  } finally { Pop-Location }
  $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app habit).Trim()
  $ok=$rows.Count -eq 2 -and !$rows.Where({$_.exitCode -ne 0 -or !$_.process}).Count -and $rows[0].process -ne $rows[1].process -and $source -eq $after
  [pscustomobject]@{app='habit';success=$ok;sourceSha256=$source;sourceUnchanged=($source -eq $after);device=$Device;physicalDevice=$false;phases=$rows} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'docs/qa/evidence/habit-process-result.json') -Encoding utf8
  if (!$ok) { exit 1 }
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
