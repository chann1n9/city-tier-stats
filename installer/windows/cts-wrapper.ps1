[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true, ValueFromPipeline = $true)]
  [string[]] $Paths
)

Set-StrictMode -Version Latest

$items = @()
foreach ($p in $Paths) {
  if ($null -ne $p -and $p.Trim() -ne "") { $items += $p }
}

for ($i = 0; $i -lt $items.Count; $i++) {
  $p = $items[$i]
  Write-Host ("[{0}/{1}] {2}" -f ($i + 1), $items.Count, $p)

  # 依赖 PATH 直接调用
  & "city-tier-stats.exe" $p

  if ($LASTEXITCODE -ne 0) {
    Write-Host "ExitCode: $LASTEXITCODE" -ForegroundColor Yellow
  }
  Write-Host ""
}

Read-Host "Done. Press Enter to close"
