# ==============================================================================
# WordPress Reset Script (PowerShell for Windows)
# ==============================================================================
[CmdletBinding()]
param (
    [switch]$All,
    [switch]$Help
)

if ($Help) {
    Write-Host "Penggunaan: .\scripts\wp-reset.ps1 [-All]" -ForegroundColor Cyan
    Write-Host "  Default : Menghapus 'wordpress/' dan 'db_data/'"
    Write-Host "  -All    : Menghapus 'wordpress/', 'db_data/', 'backups/', dan '.env'"
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$targets = @(
    (Join-Path $ProjectRoot "wordpress"),
    (Join-Path $ProjectRoot "db_data")
)

if ($All) {
    $targets += (Join-Path $ProjectRoot "backups")
    $targets += (Join-Path $ProjectRoot ".env")
    Write-Host "[Reset] Menjalankan full reset (termasuk 'backups/' dan '.env')..." -ForegroundColor Yellow
} else {
    Write-Host "[Reset] Menjalankan standard reset ('wordpress/' dan 'db_data/')..." -ForegroundColor Cyan
    Write-Host "        Tip: Gunakan '.\scripts\wp-reset.ps1 -All' untuk menyertakan folder 'backups/' dan file '.env'." -ForegroundColor DarkGray
}

foreach ($target in $targets) {
    if (Test-Path $target) {
        try {
            Remove-Item -Path $target -Recurse -Force -ErrorAction Stop
            Write-Host "deleted: $target" -ForegroundColor Green
        } catch {
            # Fallback for Windows locks / special filenames created by Docker
            & docker run --rm -v "${target}:/target" alpine sh -c "rm -rf /target/* /target/.* 2>/dev/null || true" 2>$null
            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "deleted (via fallback): $target" -ForegroundColor Green
        }
    } else {
        Write-Host "skip: $target" -ForegroundColor DarkGray
    }
}

Write-Host "[Reset] Selesai!" -ForegroundColor Cyan
