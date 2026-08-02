$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Binary = Join-Path $Root "dist\lazyai-windows-amd64.exe"
if (-not (Test-Path $Binary)) { throw "missing Windows binary: $Binary" }

$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("lazyai-win-" + [guid]::NewGuid())
$HomeDir = Join-Path $Temp "home"
$InstallDir = Join-Path $Temp "bin"
New-Item -ItemType Directory -Force -Path $HomeDir | Out-Null

try {
  $env:USERPROFILE = $HomeDir
  $env:APPDATA = Join-Path $HomeDir "AppData\Roaming"
  $env:LOCALAPPDATA = Join-Path $HomeDir "AppData\Local"
  $hash = (Get-FileHash -Algorithm SHA256 $Binary).Hash.ToLowerInvariant()

  & (Join-Path $Root "install.ps1") -BinaryPath $Binary -ExpectedSHA256 $hash -InstallDir $InstallDir -SkipPathUpdate

  foreach ($name in @("lazyai.exe", "lazyaicli.cmd", "ags.cmd", "ccs.cmd", "cxs.cmd", "lazyai.ps1")) {
    if (-not (Test-Path (Join-Path $InstallDir $name))) { throw "missing installed command: $name" }
  }

  $version = & (Join-Path $InstallDir "lazyai.exe") --version
  if ($version -notmatch '^lazyai v0\.1\.0-rc1$') { throw "unexpected version: $version" }

  $doctor = & (Join-Path $InstallDir "lazyai.exe") doctor
  if (($doctor -join "`n") -notmatch 'agy\s+missing\s+0') { throw "zero-backend doctor failed" }

  $badDir = Join-Path $Temp "bad"
  $failed = $false
  try {
    & (Join-Path $Root "install.ps1") -BinaryPath $Binary -ExpectedSHA256 ("0" * 64) -InstallDir $badDir -SkipPathUpdate
  } catch { $failed = $true }
  if (-not $failed) { throw "checksum mismatch unexpectedly succeeded" }
  if (Test-Path (Join-Path $badDir "lazyai.exe")) { throw "bad binary was installed before checksum rejection" }

  Write-Host "windows contract tests passed"
} finally {
  Remove-Item -Recurse -Force $Temp -ErrorAction SilentlyContinue
}
