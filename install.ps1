param(
  [string]$Version = "latest",
  [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "lazyai\bin"),
  [string]$BinaryPath = "",
  [string]$ExpectedSHA256 = "",
  [switch]$SkipPathUpdate
)

$ErrorActionPreference = "Stop"
$Asset = "lazyai-windows-amd64.exe"
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) ("lazyai-install-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

try {
  $StagedBinary = Join-Path $Stage "lazyai.exe"
  if ($BinaryPath) {
    Copy-Item -LiteralPath $BinaryPath -Destination $StagedBinary
  } else {
    if ($Version -eq "latest") {
      $Base = "https://github.com/jimmyliao/lazyaicli/releases/latest/download"
    } else {
      $Base = "https://github.com/jimmyliao/lazyaicli/releases/download/$Version"
    }
    Write-Host "Downloading $Base/$Asset"
    Invoke-WebRequest -UseBasicParsing -Uri "$Base/$Asset" -OutFile $StagedBinary
    $Sums = Join-Path $Stage "SHA256SUMS"
    Invoke-WebRequest -UseBasicParsing -Uri "$Base/SHA256SUMS" -OutFile $Sums
    $checksumPattern = '^([0-9a-fA-F]{64})\s+\*?' + [regex]::Escape($Asset) + '$'
    foreach ($line in Get-Content $Sums) {
      if ($line -match $checksumPattern) { $ExpectedSHA256 = $Matches[1]; break }
    }
    if (-not $ExpectedSHA256) { throw "checksum for $Asset not found" }
  }

  if ($ExpectedSHA256) {
    $Actual = (Get-FileHash -Algorithm SHA256 $StagedBinary).Hash
    if ($Actual -ne $ExpectedSHA256) { throw "checksum verification failed" }
    Write-Host "SHA-256 verified"
  }

  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  Copy-Item -LiteralPath $StagedBinary -Destination (Join-Path $InstallDir "lazyai.exe") -Force
  $InstalledIntegration = Join-Path $InstallDir "lazyai.ps1"
  $LocalIntegration = if ($PSScriptRoot) { Join-Path $PSScriptRoot "lazyai.ps1" } else { "" }
  if ($LocalIntegration -and (Test-Path $LocalIntegration)) {
    Copy-Item -LiteralPath $LocalIntegration -Destination $InstalledIntegration -Force
  } else {
    $ref = if ($Version -eq "latest") { "main" } else { $Version }
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/jimmyliao/lazyaicli/$ref/lazyai.ps1" -OutFile $InstalledIntegration
  }
  Unblock-File -Path $InstalledIntegration -ErrorAction SilentlyContinue

  $wrappers = @{ lazyaicli = ""; ags = "agy"; ccs = "claude"; cxs = "codex" }
  foreach ($entry in $wrappers.GetEnumerator()) {
    $suffix = if ($entry.Value) { " $($entry.Value)" } else { "" }
    Set-Content -Encoding ASCII -Path (Join-Path $InstallDir "$($entry.Key).cmd") -Value "@`"%~dp0lazyai.exe`"$suffix %*"
  }

  if (-not $SkipPathUpdate) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @($userPath -split ';' | Where-Object { $_ })
    if ($InstallDir -notin $parts) {
      [Environment]::SetEnvironmentVariable("Path", (($parts + $InstallDir) -join ';'), "User")
    }
    if ($InstallDir -notin ($env:Path -split ';')) { $env:Path = "$InstallDir;$env:Path" }

    $profilePath = $PROFILE.CurrentUserAllHosts
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $profilePath) | Out-Null
    $sourceLine = ". `"$(Join-Path $InstallDir 'lazyai.ps1')`""
    if (-not (Test-Path $profilePath) -or $sourceLine -notin (Get-Content $profilePath -ErrorAction SilentlyContinue)) {
      Add-Content -Path $profilePath -Value "`n# lazyai shell integration`n$sourceLine"
    }
  }

  Write-Host "lazyai installed to $InstallDir"
  Write-Host "Restart PowerShell, then run: lazyai doctor"
} finally {
  Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue
}
