#!/bin/bash
# Lance le backend FastAPI pour qu'il soit accessible depuis le LAN
# (via le port-forward Windows). A executer dans WSL depuis backend/.
#
# Usage : bash scripts/dev_lan.sh
set -e

cd "$(dirname "$0")/.."

# Active le venv si pas deja dedans
if [ -z "$VIRTUAL_ENV" ]; then
  source .venv/bin/activate
fi

# Verification basique : Docker compose up + migrations a jour
docker compose ps postgres 2>/dev/null | grep -q "Up" || {
  echo "Postgres pas demarre. Run: docker compose up -d"
  exit 1
}

echo "Backend KORA en ecoute sur 0.0.0.0:8001"
echo "Joignable depuis :"
echo "  - WSL    : http://localhost:8001/docs"
echo "  - Windows: http://localhost:8001/docs (via WSL forward)"
echo "  - Phone  : http://192.168.1.12:8001/docs (apres expose_backend_lan.ps1)"
echo ""

exec uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
