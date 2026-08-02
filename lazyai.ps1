$script:LazyAIExe = Join-Path $PSScriptRoot "lazyai.exe"

function Invoke-LazyAIResume {
  param([string[]]$Arguments)

  $direct = $false
  if ($Arguments.Count -gt 0 -and $Arguments[0] -in @("-h", "--help", "-V", "--version", "help", "default", "list", "doctor")) { $direct = $true }
  if ($Arguments.Count -gt 1 -and $Arguments[1] -in @("-h", "--help", "-V", "--version", "-l", "--list", "list", "ls")) { $direct = $true }
  if ($direct) { & $script:LazyAIExe @Arguments; return }

  $previous = $env:LAZYAI_EMIT
  $env:LAZYAI_EMIT = "1"
  try { $selected = & $script:LazyAIExe @Arguments } finally { $env:LAZYAI_EMIT = $previous }
  if ($LASTEXITCODE -ne 0 -or -not $selected) { return }

  $parts = ($selected -join "`n").Split("`t")
  if ($parts.Count -ne 3) { throw "lazyai emitted an invalid session selection" }
  $backend, $cwd, $id = $parts
  Set-Location -LiteralPath $cwd
  switch ($backend) {
    "agy"    { & agy --conversation $id }
    "claude" { & claude --resume $id }
    "codex"  { & codex resume $id }
    default  { throw "lazyai emitted an invalid backend: $backend" }
  }
}

function lazyai { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) Invoke-LazyAIResume $Arguments }
function lazyaicli { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) Invoke-LazyAIResume $Arguments }
function ags { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) Invoke-LazyAIResume (@("agy") + $Arguments) }
function ccs { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) Invoke-LazyAIResume (@("claude") + $Arguments) }
function cxs { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) Invoke-LazyAIResume (@("codex") + $Arguments) }
