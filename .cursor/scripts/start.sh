#!/usr/bin/env bash
# Per-boot reconciliation: bring up PostgreSQL and ensure the dev database,
# role and bootstrap schema exist. Long-running dev servers (backend API and
# Flutter web) run as named terminals, not here. This script must return.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[start] Starting PostgreSQL..."
sudo service postgresql start || true

echo "[start] Waiting for PostgreSQL to accept connections..."
for _ in $(seq 1 30); do
  if sudo -u postgres pg_isready -q; then break; fi
  sleep 1
done

echo "[start] Ensuring dev role and database exist..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='coreactive'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE ROLE coreactive LOGIN PASSWORD 'coreactive' CREATEDB;"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='coreactive'" | grep -q 1 \
  || sudo -u postgres createdb -O coreactive coreactive

echo "[start] Applying idempotent dev bootstrap (schema + seed)..."
PGPASSWORD=coreactive psql -h localhost -U coreactive -d coreactive \
  -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/dev-bootstrap.sql"

echo "[start] PostgreSQL ready on localhost:5432 (db=coreactive)."
