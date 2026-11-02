$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$mutex=Enter-HandyAndroidBuild
try {
  $before=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
  Push-Location (Join-Path $root 'apps/handy_bookmark')
  try {
    # Pub regenerates the release registrant without debug-only integration_test.
    # --no-pub after flutter drive leaves an incompatible generated registrant.
    $ErrorActionPreference='Continue'
    & flutter build appbundle --release *> (Join-Path $root 'docs/qa/evidence/save-aab-build.log')
    $code=$LASTEXITCODE
    $ErrorActionPreference='Stop'
  } finally { Pop-Location }
  $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py')).Trim()
  $artifact='apps/handy_bookmark/build/app/outputs/bundle/release/app-release.aab'
  $hash=if($code -eq 0){(Get-FileHash -LiteralPath (Join-Path $root $artifact) -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null}
  [pscustomobject]@{app='save';exitCode=$code;sourceSha256=$before;sourceUnchanged=($before -eq $after);artifact=$artifact;artifactSha256=$hash;signed=$false;storeReady=$false} | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/save-aab-result.json') -Encoding utf8
  Write-Output "Unsigned AAB exit=$code"
  if($code -ne 0 -or $before -ne $after){exit 1}
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
