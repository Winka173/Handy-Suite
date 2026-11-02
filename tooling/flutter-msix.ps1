param([ValidateSet('tools','keep','recall','docs','media','dev','bookmark','spend','habit','trip','boards')][string]$App = 'tools')
$ErrorActionPreference = 'Stop'
$fingerprintArgs=if($App -in @('habit','trip','boards')){@('--app',$App)}else{@()}
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceHash=(& python (Join-Path $repoRoot 'tooling/flutter-source-fingerprint.py') @fingerprintArgs).Trim()
$builds=Get-Content -LiteralPath (Join-Path $repoRoot 'docs/qa/evidence/builds-windows.json') -Raw -Encoding utf8 | ConvertFrom-Json
$verifiedBuild=@($builds | Where-Object { $_.app -eq $App -and $_.exitCode -eq 0 -and $_.sourceUnchanged -and $_.sourceSha256 -eq $sourceHash })
if ($verifiedBuild.Count -ne 1) { throw 'A successful unchanged-source Windows build of the current revision is required before packaging.' }
$release = Join-Path $repoRoot "apps/handy_$App/build/windows/x64/runner/Release"
if (!(Test-Path -LiteralPath (Join-Path $release "handy_$App.exe"))) { throw 'Build the native Windows release first.' }
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$stage = Join-Path $repoRoot ".tooling/msix-$App-$stamp"
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination $stage -Recurse
$assets = Join-Path $stage 'Assets'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile((Join-Path $repoRoot "apps/handy_$App/assets/icon.png"))
try {
  foreach ($size in @(44,150,50)) {
    $bitmap = New-Object System.Drawing.Bitmap($size,$size)
    try { $graphics=[System.Drawing.Graphics]::FromImage($bitmap); try { $graphics.DrawImage($image,0,0,$size,$size) } finally { $graphics.Dispose() }; $bitmap.Save((Join-Path $assets "Logo$size.png"),[System.Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
  }
} finally { $image.Dispose() }
$locationCapability=if($App -eq 'trip'){'<DeviceCapability Name="location"/>'}else{''}
$title = (Get-Culture).TextInfo.ToTitleCase($App)
@"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10" xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10" xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities" IgnorableNamespaces="uap rescap">
  <Identity Name="HandySuite.$title.Pilot" Publisher="CN=Handy Suite Development" Version="0.1.0.0" ProcessorArchitecture="x64" />
  <Properties><DisplayName>Handy $title</DisplayName><PublisherDisplayName>Handy Suite Development</PublisherDisplayName><Logo>Assets\Logo50.png</Logo></Properties>
  <Dependencies><TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.26100.0" /></Dependencies>
  <Resources><Resource Language="en-us"/><Resource Language="vi-vn"/></Resources>
  <Applications><Application Id="App" Executable="handy_$App.exe" EntryPoint="Windows.FullTrustApplication"><uap:VisualElements DisplayName="Handy $title" Description="Offline Handy utility" BackgroundColor="transparent" Square150x150Logo="Assets\Logo150.png" Square44x44Logo="Assets\Logo44.png" /></Application></Applications>
  <Capabilities><rescap:Capability Name="runFullTrust"/>$locationCapability</Capabilities>
</Package>
"@ | Set-Content -LiteralPath (Join-Path $stage 'AppxManifest.xml') -Encoding utf8
$makeappx = Get-ChildItem -Path 'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makeappx.exe' | Sort-Object FullName | Select-Object -Last 1
if (!$makeappx) { throw 'Windows SDK MakeAppx is unavailable.' }
$artifactDir = Join-Path $repoRoot 'artifacts/flutter'
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$output = Join-Path $artifactDir "handy-$App-$stamp-unsigned.msix"
& $makeappx.FullName pack /d $stage /p $output
if ($LASTEXITCODE -ne 0) { throw 'MSIX validation/packaging failed.' }
[pscustomobject]@{app=$App;artifact=$output;sha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant();sourceSha256=$sourceHash;makeAppxValidated=$true;signed=$false;installed=$false;storeApproved=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repoRoot "docs/qa/evidence/$App-msix-result.json") -Encoding utf8
Write-Output "Unsigned development MSIX: $output. Partner Center identity, release signing and install validation still required."
