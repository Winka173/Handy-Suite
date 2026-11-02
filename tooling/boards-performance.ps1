$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$before=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$started=(Get-Date).ToUniversalTime()
Push-Location (Join-Path $root 'apps/handy_boards')
try {
  $ErrorActionPreference='Continue'
  & flutter test --no-pub tool/indexed_performance_test.dart *> (Join-Path $root 'docs/qa/evidence/boards-indexed-performance.log')
  $code=$LASTEXITCODE
  $ErrorActionPreference='Stop'
}finally{Pop-Location}
$after=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$metrics=Join-Path $root 'docs/qa/evidence/boards-indexed-performance.json'
$fresh=(Test-Path -LiteralPath $metrics) -and (Get-Item -LiteralPath $metrics).LastWriteTimeUtc -ge $started
[pscustomobject]@{startedAt=$started.ToString('o');finishedAt=(Get-Date).ToUniversalTime().ToString('o');sourceSha256=$before;sourceUnchanged=($before -eq $after);exitCode=$code;metricsFresh=$fresh;metrics='boards-indexed-performance.json';physicalDevice=$false} | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/boards-performance-result.json') -Encoding utf8
if($code -ne 0 -or !$fresh -or $before -ne $after){exit 1}
