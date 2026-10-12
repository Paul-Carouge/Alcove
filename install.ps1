# Alcove installer for Windows (run in an elevated PowerShell):
#   irm https://github.com/Paul-Carouge/Alcove/releases/latest/download/install.ps1 | iex
$ErrorActionPreference = 'Stop'
$Repo = 'Paul-Carouge/Alcove'
$Base = if ($env:ALCOVE_DOWNLOAD_URL) { $env:ALCOVE_DOWNLOAD_URL } else { "https://github.com/$Repo/releases" }
$Dl = if ($env:ALCOVE_VERSION) { "$Base/download/v$($env:ALCOVE_VERSION.TrimStart('v'))" } else { "$Base/latest/download" }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Run PowerShell as Administrator.'
}
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw "Unsupported CPU $env:PROCESSOR_ARCHITECTURE" }

$tmp = Join-Path $env:TEMP ("alcove-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
  Write-Host 'Downloading Alcove for windows/amd64...'
  Invoke-WebRequest "$Dl/SHA256SUMS" -OutFile "$tmp\SHA256SUMS" -UseBasicParsing
  $line = Select-String -Path "$tmp\SHA256SUMS" -Pattern 'alcove_\S+_windows_amd64\.zip' | Select-Object -First 1
  if (-not $line) { throw 'No Windows build in this release.' }
  $parts = $line.Line -split '\s+'
  $expected = $parts[0]; $archive = $parts[1].TrimStart('*')
  Invoke-WebRequest "$Dl/$archive" -OutFile "$tmp\$archive" -UseBasicParsing
  $actual = (Get-FileHash "$tmp\$archive" -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $expected) { throw "Checksum mismatch for $archive" }
  Expand-Archive "$tmp\$archive" -DestinationPath $tmp
  $exe = Get-ChildItem $tmp -Recurse -Filter alcove.exe | Select-Object -First 1
  & $exe.FullName install @args
  $dir = Join-Path $env:ProgramFiles 'Alcove'
  $path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  if ($path -notlike "*$dir*") { [Environment]::SetEnvironmentVariable('Path', "$path;$dir", 'Machine') }
} finally {
  Remove-Item -Recurse -Force $tmp
}
