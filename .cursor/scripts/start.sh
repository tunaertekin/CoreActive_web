#!/usr/bin/env bash
# Per-boot startup for the CoreActive dev environment:
#   1. Bring up PostgreSQL and ensure the dev role/db exist.
#   2. Self-heal missing dependencies (node_modules / .env / Flutter .dart_tool).
#   3. Apply database migrations (node-pg-migrate: migrate:up) so the schema is
#      always current. On the baked dev/test DB this is a no-op; on an empty DB
#      the baseline migration builds the full schema.
#   4. Launch the backend API and Flutter web dev server as idempotent
#      background services (skipped if their port is already listening).
# The script reconciles state and returns; it does not stay attached.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/opt/flutter/bin:$PATH"

WORKSPACE="/agent/repos"
BACKEND="$WORKSPACE/CoreActive_backend"
FLUTTER_APP="$WORKSPACE/CoreActive-Flutter"

port_listening() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3>&- 3<&-; return 0; } || return 1; }

# --- PostgreSQL ---
echo "[start] Starting PostgreSQL..."
sudo service postgresql start || true

echo "[start] Waiting for PostgreSQL to accept connections..."
for _ in $(seq 1 30); do
  if sudo -u postgres pg_isready -q; then break; fi
  sleep 1
done

echo "[start] Ensuring dev role and database exist..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='coreactive'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE ROLE coreactive LOGIN PASSWORD 'coreactive' SUPERUSER;"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='coreactive'" | grep -q 1 \
  || sudo -u postgres createdb -O coreactive coreactive

# --- Self-heal dependencies ---
# The backend/Flutter repos are carried in the base image rather than checked
# out fresh, so their generated state (node_modules, .env, .dart_tool) may be
# absent on some boots. Refresh via install.sh only when something is missing.
if { [ -d "$BACKEND" ] && { [ ! -d "$BACKEND/node_modules" ] || [ ! -f "$BACKEND/.env" ]; }; } \
   || { [ -d "$FLUTTER_APP" ] && [ ! -d "$FLUTTER_APP/.dart_tool" ]; }; then
  echo "[start] Dependencies/.env missing; running install.sh to self-heal..."
  bash "$SCRIPT_DIR/install.sh"
fi

# --- Database migrations (node-pg-migrate) ---
if [ -d "$BACKEND/migrations" ]; then
  echo "[start] Applying database migrations (migrate:up)..."
  ( cd "$BACKEND" && npm run migrate:up ) || echo "[start] WARN: migrate:up failed; see output above."
fi

# --- Backend API (port 10000) ---
if port_listening 10000; then
  echo "[start] Backend API already running on :10000, skipping."
elif [ -d "$BACKEND" ]; then
  echo "[start] Launching backend API on :10000..."
  ( cd "$BACKEND" && nohup node server.js > /tmp/coreactive-backend.log 2>&1 & )
  for _ in $(seq 1 20); do
    if port_listening 10000; then break; fi
    sleep 1
  done
  port_listening 10000 && echo "[start] Backend API is up." \
    || echo "[start] WARN: backend API did not report ready; see /tmp/coreactive-backend.log"
fi

# --- Flutter web dev server (port 8080) ---
if port_listening 8080; then
  echo "[start] Flutter web already running on :8080, skipping."
elif [ -d "$FLUTTER_APP" ]; then
  echo "[start] Launching Flutter web dev server on :8080 (compiles in the background)..."
  ( cd "$FLUTTER_APP" && nohup flutter run -d web-server \
      --web-hostname 0.0.0.0 --web-port 8080 \
      --dart-define=API_BASE_URL=http://localhost:10000 \
      --dart-define=WS_BASE_URL=ws://localhost:10000 \
      > /tmp/coreactive-flutter-web.log 2>&1 & )
  echo "[start] Flutter web compiling; logs at /tmp/coreactive-flutter-web.log"
fi

echo "[start] Startup reconciliation complete."
