# ==============================================================================
# WordPress & Database Backup Script (PowerShell for Windows)
# ==============================================================================
# Alur:
# 1. Menyiapkan folder backup berbasis timestamp
# 2. Backup folder wp-content dari container WordPress
# 3. Backup database ke format .sql via WP-CLI / MariaDB dump
# ==============================================================================

$ErrorActionPreference = "Stop"

# Lokasi direktori root project
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Set-Location $ProjectRoot

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $ProjectRoot "backups\$Timestamp"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  WordPress Backup Process Starting...    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Waktu       : $(Get-Date)"
Write-Host "Lokasi Hasil: $BackupDir"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# ------------------------------------------------------------------------------
# 1. Backup folder wp-content dari container WordPress
# ------------------------------------------------------------------------------
Write-Host "[1/2] Mengambil backup folder 'wp-content' dari container..." -ForegroundColor Yellow

$wpContentBackupFile = Join-Path $BackupDir "wp-content.tar.gz"
$execCheck = & docker compose exec -T ols sh -c "test -d /var/www/vhosts/localhost/html/wp-content && echo OK" 2>$null

if ($execCheck -match "OK") {
    & docker compose exec -T ols tar -czf /tmp/wp-content.tar.gz -C /var/www/vhosts/localhost/html wp-content
    & docker compose cp ols:/tmp/wp-content.tar.gz $wpContentBackupFile
    & docker compose exec -T ols rm -f /tmp/wp-content.tar.gz
    Write-Host "      -> Berhasil! File tersimpan di: $wpContentBackupFile" -ForegroundColor Green
} else {
    Write-Host "      [INFO] Mengambil backup langsung dari mount lokal..." -ForegroundColor DarkYellow
    $localWpContent = Join-Path $ProjectRoot "wordpress\wp-content"
    if (Test-Path $localWpContent) {
        tar -czf $wpContentBackupFile -C (Join-Path $ProjectRoot "wordpress") wp-content
        Write-Host "      -> Berhasil (dari local mount): $wpContentBackupFile" -ForegroundColor Green
    } else {
        Write-Host "      [PERINGATAN] Folder wp-content tidak ditemukan." -ForegroundColor Red
    }
}

Write-Host ""

# ------------------------------------------------------------------------------
# 2. Backup database via SQL
# ------------------------------------------------------------------------------
Write-Host "[2/2] Mengambil backup database (.sql)..." -ForegroundColor Yellow

$dbBackupFile = Join-Path $BackupDir "database.sql"
$dbSuccess = $false

# Metode 1: Menggunakan WP-CLI
try {
    & docker compose run --rm -T --entrypoint wp wp-auto-install db export - --path=/var/www/html | Out-File -FilePath $dbBackupFile -Encoding utf8
    if ((Test-Path $dbBackupFile) -and ((Get-Item $dbBackupFile).Length -gt 100)) {
        $dbSuccess = $true
        Write-Host "      -> Berhasil diexport via WP-CLI ke: $dbBackupFile" -ForegroundColor Green
    }
} catch {
    # Fallback to next method
}

# Metode 2: Fallback ke mariadb-dump via container db
if (-not $dbSuccess) {
    Write-Host "      Mencoba metode alternatif (mariadb-dump via container db)..." -ForegroundColor DarkYellow
    try {
        & docker compose exec -T db sh -c 'mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' | Out-File -FilePath $dbBackupFile -Encoding utf8
        if ((Test-Path $dbBackupFile) -and ((Get-Item $dbBackupFile).Length -gt 100)) {
            $dbSuccess = $true
            Write-Host "      -> Berhasil diexport via MariaDB Dump ke: $dbBackupFile" -ForegroundColor Green
        }
    } catch {
        # Failed
    }
}

if (-not $dbSuccess) {
    Write-Host "      [GAGAL] Tidak dapat mengexport database. Pastikan container db sedang berjalan." -ForegroundColor Red
    if (Test-Path $dbBackupFile) { Remove-Item $dbBackupFile -Force }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Backup Selesai!                         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Daftar file di $BackupDir :"
Get-ChildItem -Path $BackupDir | Select-Object Name, @{Name="Size (MB)";Expression={[math]::Round($_.Length / 1MB, 2)}}, LastWriteTime | Format-Table -AutoSize
Write-Host "==========================================" -ForegroundColor Cyan
