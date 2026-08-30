#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# WordPress & Database Backup Script
# ==============================================================================
# Alur:
# 1. Menyiapkan folder backup berbasis timestamp
# 2. Backup folder wp-content dari container WordPress
# 3. Backup database ke format .sql via WP-CLI / MariaDB dump
# ==============================================================================

# Get the directory of the current script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Get the root directory of the project
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

# Load .env variables if file exists (ignoring comments)
if [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ".env"
  set +a
fi

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
BACKUP_DIR="backups/${TIMESTAMP}"

echo "=========================================="
echo "  WordPress Backup Process Starting...    "
echo "=========================================="
echo "Waktu       : $(date)"
echo "Lokasi Hasil: ${BACKUP_DIR}"
echo "=========================================="
echo ""

# Buat folder backup
mkdir -p "${BACKUP_DIR}"

# ------------------------------------------------------------------------------
# 1. Backup folder wp-content dari container WordPress
# ------------------------------------------------------------------------------
echo "[1/2] Mengambil backup folder 'wp-content' dari container..."

if docker compose exec -T ols sh -c 'test -d /var/www/vhosts/localhost/html/wp-content' 2>/dev/null; then
  docker compose exec -T ols sh -c 'tar -czf /tmp/wp-content.tar.gz -C /var/www/vhosts/localhost/html wp-content'
  docker compose cp ols:/tmp/wp-content.tar.gz "${BACKUP_DIR}/wp-content.tar.gz"
  docker compose exec -T ols rm -f /tmp/wp-content.tar.gz
  echo "      -> Berhasil! File tersimpan di: ${BACKUP_DIR}/wp-content.tar.gz"
else
  echo "      [INFO] Container OpenLiteSpeed tidak aktif via exec. Mengambil dari volume lokal..."
  if [ -d "wordpress/wp-content" ]; then
    tar -czf "${BACKUP_DIR}/wp-content.tar.gz" -C wordpress wp-content
    echo "      -> Berhasil (dari local mount): ${BACKUP_DIR}/wp-content.tar.gz"
  else
    echo "      [PERINGATAN] Folder wp-content tidak ditemukan."
  fi
fi

echo ""

# ------------------------------------------------------------------------------
# 2. Backup database via SQL
# ------------------------------------------------------------------------------
echo "[2/2] Mengambil backup database (.sql)..."
DB_BACKUP_SUCCESS=false

# Metode 1: Menggunakan WP-CLI
if docker compose run --rm -T --entrypoint wp wp-auto-install db export - --path=/var/www/html > "${BACKUP_DIR}/database.sql" 2>/dev/null; then
  if [ -s "${BACKUP_DIR}/database.sql" ]; then
    DB_BACKUP_SUCCESS=true
    echo "      -> Berhasil diexport via WP-CLI ke: ${BACKUP_DIR}/database.sql"
  fi
fi

# Metode 2: Fallback ke mariadb-dump / mysqldump via container db
if [ "$DB_BACKUP_SUCCESS" = false ]; then
  echo "      Mencoba metode alternatif (mariadb-dump via container db)..."
  
  DB_USER_CMD="${DB_ROOT_PASSWORD:+root}"
  DB_USER_CMD="${DB_USER_CMD:-${DB_USER:-root}}"
  DB_PASS_CMD="${DB_ROOT_PASSWORD:-${DB_PASSWORD:-}}"
  TARGET_DB="${DB_NAME:-wordpress_db}"

  if docker compose exec -T db mariadb-dump -u"${DB_USER_CMD}" -p"${DB_PASS_CMD}" "${TARGET_DB}" > "${BACKUP_DIR}/database.sql" 2>/dev/null || \
     docker compose exec -T db mysqldump -u"${DB_USER_CMD}" -p"${DB_PASS_CMD}" "${TARGET_DB}" > "${BACKUP_DIR}/database.sql" 2>/dev/null; then
    
    if [ -s "${BACKUP_DIR}/database.sql" ]; then
      DB_BACKUP_SUCCESS=true
      echo "      -> Berhasil diexport via MariaDB Dump ke: ${BACKUP_DIR}/database.sql"
    fi
  fi
fi

if [ "$DB_BACKUP_SUCCESS" = false ]; then
  echo "      [GAGAL] Tidak dapat mengexport database. Pastikan container db sedang berjalan."
  rm -f "${BACKUP_DIR}/database.sql"
fi

echo ""
echo "=========================================="
echo "  Backup Selesai!                         "
echo "=========================================="
echo "Daftar file di ${BACKUP_DIR}:"
ls -lh "${BACKUP_DIR}"
echo "=========================================="
