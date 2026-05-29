#!/usr/bin/env bash
# Smoke test end-to-end : health + OTP flow.
# Lance uvicorn en arriere-plan, hit les endpoints, stoppe uvicorn.
set -euo pipefail

cd "$(dirname "$0")/.."
source .venv/bin/activate

PORT=${PORT:-8001}

# Demarre uvicorn
nohup uvicorn app.main:app --port "$PORT" > /tmp/kora-uvicorn.log 2>&1 &
UVI_PID=$!
trap "kill ${UVI_PID} 2>/dev/null || true" EXIT
echo "Uvicorn PID=${UVI_PID}"
sleep 3

echo
echo "=== GET /api/v1/health ==="
curl -s http://localhost:8001/api/v1/health
echo

echo
echo "=== GET /api/v1/health/ready ==="
curl -s http://localhost:8001/api/v1/health/ready
echo

echo
echo "=== POST /api/v1/auth/otp/request ==="
RESP=$(curl -s -X POST http://localhost:8001/api/v1/auth/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"phone": "0712345678"}')
echo "$RESP" | python3 -m json.tool

OTP=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["debug_otp"])')
echo ">> OTP extrait : $OTP"

echo
echo "=== POST /api/v1/auth/otp/verify (bon code) ==="
curl -s -X POST http://localhost:8001/api/v1/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d "{\"phone\": \"0712345678\", \"code\": \"${OTP}\"}" \
  | python3 -m json.tool

echo
echo "=== POST /api/v1/auth/otp/request 2e fois (devrait throttle 429) ==="
curl -s -w '\nHTTP %{http_code}\n' -X POST http://localhost:8001/api/v1/auth/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"phone": "0712345678"}'

echo
echo "=== Phone invalide (devrait 400) ==="
curl -s -w '\nHTTP %{http_code}\n' -X POST http://localhost:8001/api/v1/auth/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"phone": "123"}'

echo
echo "=== Verif user cree en base ==="
PGPASSWORD=kora_dev_password psql -h localhost -p 5433 -U kora -d kora \
  -c "SELECT id, phone_e164, last_login_at FROM users;"
