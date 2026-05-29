#!/usr/bin/env bash
# Smoke test tranche 5 : commission KORA + webhook CinetPay.
set -euo pipefail

PORT="${PORT:-8001}"
BASE="http://localhost:${PORT}/api/v1"
PHONE="${PHONE:?fournir PHONE=07xxxxxxxx}"

echo "=== Auth ==="
RESP=$(curl -s -X POST "${BASE}/auth/otp/request" -H 'Content-Type: application/json' -d "{\"phone\": \"${PHONE}\"}")
OTP=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["debug_otp"])')
TOKEN=$(curl -s -X POST "${BASE}/auth/otp/verify" -H 'Content-Type: application/json' \
  -d "{\"phone\": \"${PHONE}\", \"code\": \"${OTP}\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
AUTH="Authorization: Bearer ${TOKEN}"
echo ">> JWT ${#TOKEN} chars"
echo

echo "=== Cree un goal et le pousse a 100% ==="
GOAL=$(curl -s -X POST "${BASE}/goals" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"title": "Smartphone", "target_amount_xof": 100000}')
GOAL_ID=$(echo "$GOAL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
echo ">> goal_id = $GOAL_ID"

curl -s -o /dev/null -X POST "${BASE}/goals/${GOAL_ID}/contribute" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"amount_xof": 100000}'

curl -s "${BASE}/goals/${GOAL_ID}" -H "$AUTH" | python3 -m json.tool
echo

echo "=== Estimation commission ==="
curl -s "${BASE}/payments/commission/${GOAL_ID}/estimate" -H "$AUTH" | python3 -m json.tool
echo

echo "=== Initiation paiement ==="
PAY=$(curl -s -X POST "${BASE}/payments/commission/${GOAL_ID}/initiate" -H "$AUTH")
echo "$PAY" | python3 -m json.tool
PAY_ID=$(echo "$PAY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
PROVIDER_REF=$(echo "$PAY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["provider_ref"])')
echo

echo "=== 2e initiation (devrait renvoyer le meme paiement) ==="
curl -s -X POST "${BASE}/payments/commission/${GOAL_ID}/initiate" -H "$AUTH" | python3 -m json.tool
echo

echo "=== Liste paiements ==="
curl -s "${BASE}/payments" -H "$AUTH" | python3 -m json.tool
echo

echo "=== Tentative sur goal non atteint (409 attendu) ==="
GOAL2=$(curl -s -X POST "${BASE}/goals" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"title": "Voyage", "target_amount_xof": 200000}')
GOAL2_ID=$(echo "$GOAL2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
curl -s -w '\nHTTP %{http_code}\n' -X POST "${BASE}/payments/commission/${GOAL2_ID}/initiate" -H "$AUTH"
echo

echo "=== Webhook CinetPay : ignore (paiement avec provider LOGGING, ref differente) ==="
curl -s -X POST "${BASE}/payments/webhook/cinetpay" -H 'Content-Type: application/json' \
  -d '{"cpm_trans_id": "unknown-ref-xyz", "cpm_amount": 500, "cpm_currency": "XOF", "cpm_result": "00"}' \
  | python3 -m json.tool
