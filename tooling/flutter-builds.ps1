param([string[]]$Apps=@('tools','keep','recall'),[ValidateSet('windows','web','apk')][string]$Target='web')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$androidMutex = $null
if ($Target -eq 'apk') { $androidMutex = Enter-HandyAndroidBuild }
try {
$results=@()
foreach($app in $Apps){
  $fingerprintArgs=if($app -in @('habit','trip')){@('--app',$app)}else{@()}
  if($app -notin @('tools','keep','recall','docs','media','dev','bookmark','spend','habit','trip')){throw 'Unknown app'}
  $log=Join-Path $root "docs/qa/evidence/$app-$Target-build.log"
  Push-Location (Join-Path $root "apps/handy_$app")
  try{
    $started=Get-Date
    $sourceBefore = (& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') @fingerprintArgs).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not fingerprint Flutter source.' }
    $arguments=@('build',$Target,'--no-pub')
    if($Target -eq 'apk'){$arguments+='--debug'}else{$arguments+='--release'}
    if($Target -eq 'web'){$arguments+='--no-web-resources-cdn'}
    $ErrorActionPreference='Continue'
    & flutter @arguments *> $log
    $result=$LASTEXITCODE
    if ($result -eq 0 -and $Target -eq 'web') {
      $node = Join-Path $root '.tooling/node_modules/node/bin/node.exe'
      if (!(Test-Path -LiteralPath $node)) { $node = 'node' }
      Push-Location $root
      try { & $node (Join-Path $root 'tooling/flutter-offline.mjs') "handy_$app" *>> $log; $result=$LASTEXITCODE }
      finally { Pop-Location }
    }
    $ErrorActionPreference='Stop'
    $sourceAfter = (& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') @fingerprintArgs).Trim()
    $artifactPath=$null
    $artifactSha256=$null
    if($result -eq 0 -and $sourceBefore -eq $sourceAfter -and $Target -eq 'apk') {
      # Integration builds reuse app-debug.apk; preserve the actual app entrypoint separately.
      $artifactDir=Join-Path $root "artifacts/flutter/handy_$app/android"
      New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
      $artifactPath="artifacts/flutter/handy_$app/android/handy-$app-pilot-debug.apk"
      Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-debug.apk' -Destination (Join-Path $root $artifactPath) -Force
      $artifactSha256=(Get-FileHash -LiteralPath (Join-Path $root $artifactPath) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $results+= [pscustomobject]@{app=$app;target=$Target;exitCode=$result;sourceSha256=$sourceBefore;sourceUnchanged=($sourceBefore -eq $sourceAfter);artifact=$artifactPath;artifactSha256=$artifactSha256;startedAt=$started.ToUniversalTime().ToString('o');elapsedSeconds=[Math]::Round(((Get-Date)-$started).TotalSeconds,2)}
  }finally{Pop-Location}
}
$summary = Join-Path $root "docs/qa/evidence/builds-$Target.json"
$previous = @()
if (Test-Path -LiteralPath $summary) {
  $existingResults = Get-Content -LiteralPath $summary -Raw -Encoding utf8 | ConvertFrom-Json
  foreach ($entry in $existingResults) {
    if ($entry.app -notin $Apps) { $previous += $entry }
  }
}
ConvertTo-Json -InputObject (@($previous) + @($results)) -Depth 4 | Set-Content -LiteralPath $summary -Encoding utf8
$results|Format-Table
if($results.Where({$_.exitCode -ne 0 -or !$_.sourceUnchanged}).Count){exit 1}
} finally {
  if ($null -ne $androidMutex) { $androidMutex.ReleaseMutex(); $androidMutex.Dispose() }
}
