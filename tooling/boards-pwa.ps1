$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$before=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
$pattern='handy_boards worker'
Push-Location $root
try{
  $ErrorActionPreference='Continue'
  & (Join-Path $root '.tooling/node_modules/node/bin/node.exe') node_modules/vitest/vitest.mjs run --config tooling/vitest.pwa.config.ts --reporter=verbose -t $pattern *> (Join-Path $root 'docs/qa/evidence/boards-pwa-tests.log')
  $code=$LASTEXITCODE
  $ErrorActionPreference='Stop'
}finally{Pop-Location}
$after=(& python (Join-Path $PSScriptRoot 'flutter-source-fingerprint.py') --app boards).Trim()
[pscustomobject]@{app='boards';exitCode=$code;sourceSha256=$before;sourceUnchanged=($before -eq $after);testPattern=$pattern;realBrowser=$false} | ConvertTo-Json | Set-Content (Join-Path $root 'docs/qa/evidence/boards-pwa-result.json') -Encoding utf8
if($code -ne 0 -or $before -ne $after){exit 1}
