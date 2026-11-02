$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$before=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$started=(Get-Date).ToUniversalTime()
$env:SHOTS_DIR=Join-Path $root 'review-shots/boards'
$env:FLUTTER_ROOT=Split-Path -Parent (Split-Path -Parent (Get-Command flutter).Source)
Push-Location (Join-Path $root 'apps/handy_boards')
try{
  $ErrorActionPreference='Continue'
  & flutter test --no-pub tool/screens_test.dart tool/detail_screens_test.dart *> (Join-Path $root 'docs/qa/evidence/boards-review-shots.log')
  $code=$LASTEXITCODE
  $ErrorActionPreference='Stop'
}finally{Pop-Location}
$after=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$images=@(Get-ChildItem -LiteralPath $env:SHOTS_DIR -Filter '*.png')
$fresh=$images.Count -eq 103 -and @($images|Where-Object {$_.LastWriteTimeUtc -lt $started}).Count -eq 0
[pscustomobject]@{startedAt=$started.ToString('o');finishedAt=(Get-Date).ToUniversalTime().ToString('o');sourceSha256=$before;sourceUnchanged=($before -eq $after);exitCode=$code;imageCount=$images.Count;allImagesFresh=$fresh;physicalDevice=$false;browser=$false} | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/boards-shots-result.json') -Encoding utf8
if($code -ne 0 -or !$fresh -or $before -ne $after){exit 1}
