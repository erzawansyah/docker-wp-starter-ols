# WordPress Docker Starter Kit (OpenLiteSpeed Edition)

A **100% automated, high-performance** WordPress Docker Compose starter kit powered by **OpenLiteSpeed (OLS) + LSPHP 8.3 + LiteSpeed Cache (LSCache)**.

Simply configure `.env` and run `docker compose up -d`. The system inside Docker automatically handles database health checks, downloading core files, configuring `wp-config.php`, installing WordPress, and activating the **LiteSpeed Cache** plugin automatically via WP-CLI!

---

## ⚡ Architecture Overview

```
[ Browser / Client ]
         │ (Port ${HTTP_PORT})
         ▼
 ┌──────────────────────────────────────────────────────────┐
 │  OpenLiteSpeed Server (litespeedtech/openlitespeed)      │
 │  - Native LSCache Module (Server-level cache)            │
 │  - LSPHP 8.3 Engine                                      │
 │  - WebAdmin Console on port ${OLS_ADMIN_PORT} (7080)     │
 └──────────────────────────────────────────────────────────┘
         │                                      │
         │ (Filesystem Mount)                   │ (MySQL TCP: 3306)
         ▼                                      ▼
 ┌───────────────────────────┐      ┌───────────────────────┐
 │  Local Volume             │      │  Database (MariaDB)   │
 │  (/var/www/vhosts/.../html│      │    (mariadb:10.11)    │
 └───────────────────────────┘      └───────────────────────┘
```

* **OpenLiteSpeed (`openlitespeed:1.8.2-lsphp83`)**: Server web berkinerja tinggi dengan dukungan HTTP/3 (QUIC) dan server-level cache bawaan.
* **LiteSpeed Cache (LSCache) Plugin**: Terpasang dan aktif otomatis saat inisialisasi.
* **OpenLiteSpeed WebAdmin Console**: Tersedia di port `7080` (User: `admin`, Password: `${OLS_ADMIN_PASSWORD}`).
* **MariaDB (`mariadb:10.11`)**: Database relasional cepat dengan Docker named volume untuk stabilitas dan performa I/O maksimal.

---

## 🚀 How to Use

### 1. Copy the Template Folder
Copy folder `wp-starter-ols` ke direktori project baru Anda:
```bash
cp -r wp-starter-ols my-ols-project
cd my-ols-project
```

### 2. Configure `.env`
Copy `.env.example` ke `.env` (jika belum ada), lalu sesuaikan variabelnya:
```dotenv
COMPOSE_PROJECT_NAME=my-ols-project
HTTP_PORT=8080
OLS_ADMIN_PORT=7080
OLS_ADMIN_PASSWORD=SecretOlsPassword123!
PMA_PORT=8081
WP_TITLE="My OpenLiteSpeed Website"
WP_URL=http://localhost:8080
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=SecretPassword123!
WP_ADMIN_EMAIL=admin@example.com
```

### 3. Run Docker Compose
Jalankan satu perintah ini di terminal:
```bash
docker compose up -d
```

🎉 **Selesai!**
Container `wp-auto-install` di dalam Docker akan secara otomatis:
1. Menunggu database MariaDB siap (*healthy*).
2. Mengunduh core WordPress dan membuat `wp-config.php`.
3. Menjalankan `wp core install`.
4. Menginstal & mengaktifkan plugin **LiteSpeed Cache (LSCache)**.
5. Berhenti dengan aman (*graceful exit*).

---

## 🌐 Accessing the Services

- **WordPress Site**: `http://localhost:<HTTP_PORT>` (contoh: `http://localhost:8080`)
- **WordPress Admin**: `http://localhost:<HTTP_PORT>/wp-admin`
- **OpenLiteSpeed WebAdmin Console**: `http://localhost:<OLS_ADMIN_PORT>` (contoh: `http://localhost:7080`)
  - User: `admin`
  - Password: `${OLS_ADMIN_PASSWORD}` (dari file `.env`)
- **phpMyAdmin**: `http://localhost:<PMA_PORT>` (contoh: `http://localhost:8081`)

---

## 🛠️ Useful Commands

- **Check container status**: `docker compose ps`
- **View auto-installation logs**: `docker logs <COMPOSE_PROJECT_NAME>-auto-install`
- **Stop containers**: `docker compose stop`
- **Remove containers (data database & file web tetap aman)**: `docker compose down`
- **Run manual WP-CLI commands**:
  ```bash
  docker compose run --rm --entrypoint wp wp-auto-install plugin list
  docker compose run --rm --entrypoint wp wp-auto-install lscache-purge all
  ```
- **Backup WordPress (`wp-content` + Database SQL)**:
  ```bash
  ./scripts/wp-backup.sh
  ```
- **Reset Environment (Hapus database lokal & file WordPress)**:
  ```bash
  # Standard reset (wordpress/ & db_data/)
  ./scripts/wp-reset.sh

  # Full reset (termasuk backups/ & .env)
  ./scripts/wp-reset.sh --all
  ```
