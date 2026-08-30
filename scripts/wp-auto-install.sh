#!/bin/sh
set -eu

# Increase PHP memory limit for WP-CLI operations
wp() {
  php -d memory_limit=512M /usr/local/bin/wp "$@"
}

WP_PATH="/var/www/html"

echo "[Auto-Installer] Starting OpenLiteSpeed WordPress initialization..."

# 1. Download WordPress core if missing
if [ ! -f "${WP_PATH}/wp-includes/version.php" ]; then
  echo "[Auto-Installer] WordPress core files not found. Downloading..."
  wp core download --path="${WP_PATH}" --locale="${WP_LOCALE:-en_US}"
fi

# 2. Generate wp-config.php if missing
if [ ! -f "${WP_PATH}/wp-config.php" ]; then
  echo "[Auto-Installer] Generating wp-config.php..."
  wp config create \
    --path="${WP_PATH}" \
    --dbname="${WORDPRESS_DB_NAME}" \
    --dbuser="${WORDPRESS_DB_USER}" \
    --dbpass="${WORDPRESS_DB_PASSWORD}" \
    --dbhost="${WORDPRESS_DB_HOST}" \
    --extra-php="if (!defined('WP_DEBUG')) { define('WP_DEBUG', true); }
if (!defined('WP_DEBUG_LOG')) { define('WP_DEBUG_LOG', true); }
if (!defined('WP_DEBUG_DISPLAY')) { define('WP_DEBUG_DISPLAY', false); }"
fi

echo "[Auto-Installer] WordPress core and wp-config.php are ready."

# 3. Check if WordPress is already installed
if wp core is-installed --path="${WP_PATH}" 2>/dev/null; then
  echo "[Auto-Installer] WordPress is already installed."
  exit 0
fi

echo "[Auto-Installer] Installing WordPress..."

# 4. Install WordPress
until wp core install \
  --path="${WP_PATH}" \
  --url="${WP_URL}" \
  --title="${WP_TITLE}" \
  --admin_user="${WP_ADMIN_USER}" \
  --admin_password="${WP_ADMIN_PASSWORD}" \
  --admin_email="${WP_ADMIN_EMAIL}" \
  --locale="${WP_LOCALE:-en_US}" \
  --skip-email; do

  echo "[Auto-Installer] Installation has not succeeded yet; retrying in 3 seconds..."
  sleep 3
done

echo "[Auto-Installer] Installing and activating LiteSpeed Cache (LSCache) plugin..."
wp plugin install litespeed-cache --activate --path="${WP_PATH}" || true

echo "[Auto-Installer] Setting up permalink structure..."
wp rewrite structure '/%postname%/' --path="${WP_PATH}" || true

echo "[Auto-Installer] OpenLiteSpeed WordPress setup completed successfully!"
