#!/usr/bin/env bash
# Smoke test des endpoints (suppose uvicorn deja en route).
set -euo pipefail

PORT="${PORT:-8001}"
BASE="http://localhost:${PORT}/api/v1"
PHONE="0712345678"

echo "=== GET /health ==="
curl -s "${BASE}/health"
echo; echo

echo "=== GET /health/ready ==="
curl -s "${BASE}/health/ready"
echo; echo

echo "=== POST /auth/otp/request ==="
RESP=$(curl -s -X POST "${BASE}/auth/otp/request" \
  -H 'Content-Type: application/json' \
  -d "{\"phone\": \"${PHONE}\"}")
echo "${RESP}" | python3 -m json.tool

OTP=$(echo "${RESP}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["debug_otp"])')
echo ">> OTP recupere : ${OTP}"
echo

echo "=== POST /auth/otp/verify (bon code) ==="
curl -s -X POST "${BASE}/auth/otp/verify" \
  -H 'Content-Type: application/json' \
  -d "{\"phone\": \"${PHONE}\", \"code\": \"${OTP}\"}" \
  | python3 -m json.tool
echo

echo "=== POST /auth/otp/request 2e fois (throttle 429 attendu) ==="
curl -s -w '\nHTTP %{http_code}\n' -X POST "${BASE}/auth/otp/request" \
  -H 'Content-Type: application/json' \
  -d "{\"phone\": \"${PHONE}\"}"
echo

echo "=== POST /auth/otp/request avec phone invalide (400 attendu) ==="
curl -s -w '\nHTTP %{http_code}\n' -X POST "${BASE}/auth/otp/request" \
  -H 'Content-Type: application/json' \
  -d '{"phone": "123"}'
echo

echo "=== User en base ==="
PGPASSWORD=kora_dev_password psql -h localhost -p 5433 -U kora -d kora \
  -c "SELECT id, phone_e164, last_login_at FROM users;"
