$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$before=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$started=(Get-Date).ToUniversalTime().ToString('o')
$checks=@()
foreach($entry in @(
  @{name='engine';directory='packages/handy_boards_engine';analyzer='dart'},
  @{name='app';directory='apps/handy_boards';analyzer='flutter'}
)) {
  Push-Location (Join-Path $root $entry.directory)
  try {
    $ErrorActionPreference='Continue'
    & dart format --output=none --set-exit-if-changed lib test *> (Join-Path $root "docs/qa/evidence/boards-$($entry.name)-format.log")
    $formatCode=$LASTEXITCODE
    if($entry.analyzer -eq 'dart') {
      & dart analyze *> (Join-Path $root "docs/qa/evidence/boards-$($entry.name)-analyze.log")
    } else {
      & flutter analyze --no-pub *> (Join-Path $root "docs/qa/evidence/boards-$($entry.name)-analyze.log")
    }
    $analyzeCode=$LASTEXITCODE
    & flutter test --no-pub *> (Join-Path $root "docs/qa/evidence/boards-$($entry.name)-tests.log")
    $testCode=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    $checks += [pscustomobject]@{package=$entry.directory;formatExitCode=$formatCode;analyzeExitCode=$analyzeCode;testExitCode=$testCode}
  } finally { Pop-Location }
}
$after=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$passed=@($checks|Where-Object {$_.formatExitCode -ne 0 -or $_.analyzeExitCode -ne 0 -or $_.testExitCode -ne 0}).Count -eq 0
[pscustomobject]@{startedAt=$started;finishedAt=(Get-Date).ToUniversalTime().ToString('o');sourceSha256=$before;sourceUnchanged=($before -eq $after);passed=$passed;checks=$checks} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'docs/qa/evidence/boards-host-result.json') -Encoding utf8
if(!$passed -or $before -ne $after){exit 1}
