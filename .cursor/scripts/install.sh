#!/usr/bin/env bash
# Idempotent dependency refresh for the CoreActive dev environment.
# System packages (PostgreSQL, Flutter SDK, Node) are provided by the base
# snapshot; this script only refreshes source-derived state after checkout.
set -euo pipefail

export PATH="/opt/flutter/bin:$PATH"

WORKSPACE="/agent/repos"
BACKEND="$WORKSPACE/CoreActive_backend"
FLUTTER_APP="$WORKSPACE/CoreActive-Flutter"

if [ -d "$BACKEND" ]; then
  echo "[install] Installing backend dependencies (npm)..."
  ( cd "$BACKEND" && ( npm ci --no-audit --no-fund || npm install --no-audit --no-fund ) )

  # Generate a local dev .env if missing. Values are dev-only and this file is
  # gitignored, so no secrets are committed.
  if [ ! -f "$BACKEND/.env" ]; then
    echo "[install] Writing backend .env with local dev defaults..."
    cat > "$BACKEND/.env" <<'ENV'
NODE_ENV=development
PORT=10000
DATABASE_URL=postgres://coreactive:coreactive@localhost:5432/coreactive
DB_SSL_REJECT_UNAUTHORIZED=false
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080,http://localhost:3000
IDENTITY_LOGIN_CONTEXT_SECRET=dev-login-context-secret-please-override-in-prod
SECRET_ENCRYPTION_KEY=dev0000000000000000000000000000000000000000000=
TODO_REMINDERS_AUTO=false
PUSH_CAMPAIGNS_AUTO=false
EMAIL_SUMMARY_AUTO=false
BIRTHDAY_NOTIFICATIONS_AUTO=false
TCMB_SYNC_AUTO=false
ENV
  fi
fi

if [ -d "$FLUTTER_APP" ]; then
  echo "[install] Fetching Flutter packages..."
  git config --global --add safe.directory /opt/flutter || true
  ( cd "$FLUTTER_APP" && flutter precache --web && flutter pub get )
fi

echo "[install] Done."
