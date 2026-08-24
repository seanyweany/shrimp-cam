<#
  Keeps the desk camera online, forever.

  Opens the GitHub Page in host mode inside a throwaway Chromium profile
  (which is what actually grabs the webcam and speaks WebRTC) and relaunches
  it if it ever dies. Ctrl+C to stop.

      .\shrimp-cam.ps1                       # generates a key once, reuses it
      .\shrimp-cam.ps1 -Key "your-own-key"
#>
[CmdletBinding()]
param(
  [string] $Key        = '',
  [string] $Url        = 'https://seanyweany.github.io/shrimp-cam/',
  [string] $Camera     = '',
  [string] $ProfileDir = "$env:LocalAppData\shrimp-cam",
  [string] $KeyFile    = (Join-Path $PSScriptRoot 'key.txt')
)

# No key given? Keep one on disk, so the share link survives a restart.
if (-not $Key) {
  if (-not (Test-Path $KeyFile)) {
    $bytes = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [System.BitConverter]::ToString($bytes).Replace('-', '').ToLower() |
      Set-Content -Path $KeyFile -Encoding Ascii -NoNewline
    Write-Host "new key -> $KeyFile"
  }
  $Key = (Get-Content -Path $KeyFile -Raw).Trim()
}

# cmd.exe does not expand PowerShell subexpressions. A key still carrying
# shell punctuation is an unexpanded command, not a secret.
if ($Key -match '[\$\(\)\[\]]') {
  throw "-Key is an unexpanded expression, not a key: $Key`nDrop the -Key argument and let this script generate one."
}
if ($Key.Length -lt 16) {
  throw "-Key is short enough to guess. Use 16+ characters, or drop -Key and let this script generate one."
}

$exe = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
  "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $exe) { throw 'Chrome or Edge is required.' }

$watchLink = "$Url#key=" + [uri]::EscapeDataString($Key)
$hostLink  = "$watchLink&host=1"
if ($Camera) { $hostLink += '&cam=' + [uri]::EscapeDataString($Camera) }

Write-Host "browser : $exe"
Write-Host "share   : $watchLink"
Write-Host ''

$browserArgs = @(
  "--user-data-dir=`"$ProfileDir`""
  '--use-fake-ui-for-media-stream'              # grant the real camera, no prompt
  '--autoplay-policy=no-user-gesture-required'
  '--disable-background-timer-throttling'       # keep streaming when minimised
  '--disable-backgrounding-occluded-windows'
  '--disable-renderer-backgrounding'
  '--no-first-run'
  '--no-default-browser-check'
  '--window-size=480,320'
  "--app=`"$hostLink`""
)

while ($true) {
  Write-Host "$(Get-Date -Format 'HH:mm:ss')  live"
  Start-Process -FilePath $exe -ArgumentList $browserArgs -Wait
  Write-Host "$(Get-Date -Format 'HH:mm:ss')  browser closed, restarting in 5s"
  Start-Sleep -Seconds 5
}
