#!/bin/bash
# Point d'entree Render : migrations puis serveur.
# (Le free tier Render n'a pas de preDeployCommand, donc on chaine ici.)
set -e

echo "==> Applying Alembic migrations..."
alembic upgrade head

echo "==> Starting uvicorn on port ${PORT:-8000}"
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
