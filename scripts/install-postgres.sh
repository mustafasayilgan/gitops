#!/bin/bash
# Ref: https://www.postgresql.org/download/linux/ubuntu/
#
#   sudo ./scripts/install-postgres.sh          # distro package
#   sudo PG_VERSION=18 ./scripts/install-postgres.sh   # PGDG version
#   sudo DB_NAME=myapp DB_USER=myuser DB_PASS=secret ./scripts/install-postgres.sh
set -euo pipefail

DB_NAME="${DB_NAME:-hepapi}"
DB_USER="${DB_USER:-hepapi}"
DB_PASS="${DB_PASS:-changeme}"
PG_VERSION="${PG_VERSION:-}"

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo $0" >&2; exit 1; }

apt-get update -y

if [ -n "${PG_VERSION}" ]; then
  apt-get install -y postgresql-common
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
  apt-get install -y "postgresql-${PG_VERSION}"
else
  apt-get install -y postgresql
fi

systemctl enable --now postgresql

# create role + db
sudo -u postgres createuser "${DB_USER}" 2>/dev/null || true
sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}" 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

echo "ready: db=${DB_NAME} user=${DB_USER}"
echo "test:  sudo -u postgres psql -d ${DB_NAME} -c 'SELECT 1;'"