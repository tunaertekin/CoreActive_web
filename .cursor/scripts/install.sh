#!/usr/bin/env bash
# Idempotent setup for the CoreActive web (static Flutter build) dev environment.
#
# This repository contains a *pre-compiled* Flutter web bundle (index.html,
# main.dart.js, assets/, canvaskit/, ...). There is no Dart source to compile,
# so there are no package dependencies to install. The dev environment simply
# serves the bundle over HTTP with SPA fallback, mirroring production hosting
# (see web.config). We therefore only sanity-check the toolchain and bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[install] Verifying Python 3 is available..."
python3 --version

echo "[install] Verifying the compiled web bundle is present..."
missing=0
for f in index.html flutter_bootstrap.js main.dart.js; do
  if [ ! -f "$REPO_ROOT/$f" ]; then
    echo "[install] ERROR: expected bundle file missing: $f" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || { echo "[install] Bundle incomplete." >&2; exit 1; }

echo "[install] Done. Bundle is ready to be served (see .cursor/scripts/serve.py)."
