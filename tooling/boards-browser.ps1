$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$before=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$started=(Get-Date).ToUniversalTime().ToString('o')
if (!$env:CHROME_EXECUTABLE) {
  $edge='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
  if(Test-Path -LiteralPath $edge){$env:CHROME_EXECUTABLE=$edge}
}
Push-Location (Join-Path $root 'apps/handy_boards')
try {
  $ErrorActionPreference='Continue'
  & dart test --platform chrome test/browser_store_test.dart *> (Join-Path $root 'docs/qa/evidence/boards-browser-tests.log')
  $code=$LASTEXITCODE
  $ErrorActionPreference='Stop'
}finally{Pop-Location}
$after=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
[pscustomobject]@{startedAt=$started;finishedAt=(Get-Date).ToUniversalTime().ToString('o');sourceSha256=$before;sourceUnchanged=($before -eq $after);exitCode=$code;browser=$true;physicalDevice=$false;scope='Real IndexedDB: Unicode paging, async ZIP round trip/cancel, immutable assets, Undo, competing writers. Pure Dart browser runner avoids Flutter Windows CanvasKit test-server routing failure.'} | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/boards-browser-result.json') -Encoding utf8
if($code -ne 0 -or $before -ne $after){exit 1}
