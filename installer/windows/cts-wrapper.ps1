[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]] $Paths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

try {
  $items = @()
  foreach ($p in $Paths) {
    if (-not [string]::IsNullOrWhiteSpace($p)) { $items += $p }
  }

  if ($items.Count -eq 0) {
    Write-Host "No input paths provided." -ForegroundColor Yellow
    exit 2
  }

  for ($i = 0; $i -lt $items.Count; $i++) {
    $p = $items[$i]
    Write-Host ("[{0}/{1}] {2}" -f ($i + 1), $items.Count, $p)

    # 依赖安装时写入 PATH：直接调用
    & "city-tier-stats.exe" $p

    if ($LASTEXITCODE -ne 0) {
      Write-Host "ExitCode: $LASTEXITCODE" -ForegroundColor Yellow
    }

    Write-Host ""
  }
}
catch {
  Write-Host "ERROR:" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
  Read-Host "Done. Press Enter to close"
}
