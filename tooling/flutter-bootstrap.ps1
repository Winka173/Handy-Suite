$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $apps = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'apps') -Directory -Filter 'handy_*')
  $resolved = $false
  # Flutter updates workspace apps sequentially; a new plugin can require one pass per app.
  for ($attempt = 0; $attempt -lt $apps.Count + 2; $attempt++) {
    $ErrorActionPreference = 'Continue'
    flutter pub get
    $pubResult = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    foreach ($app in $apps) {
      $pluginFile = Join-Path $app.FullName '.flutter-plugins-dependencies'
      if (!(Test-Path -LiteralPath $pluginFile)) { continue }
      $plugins = Get-Content -LiteralPath $pluginFile -Raw -Encoding utf8 | ConvertFrom-Json
      $linkRoot = Join-Path $app.FullName 'windows/flutter/ephemeral/.plugin_symlinks'
      New-Item -ItemType Directory -Force -Path $linkRoot | Out-Null
      foreach ($plugin in $plugins.plugins.windows) {
        $linkPath = Join-Path $linkRoot $plugin.name
        if (!(Test-Path -LiteralPath $linkPath)) { New-Item -ItemType Junction -Path $linkPath -Target $plugin.path | Out-Null }
      }
    }
    if ($pubResult -eq 0) { $resolved = $true; break }
  }
  if (!$resolved) { throw 'Flutter dependency resolution failed. Inspect output; source files are preserved.' }
} finally { Pop-Location }
