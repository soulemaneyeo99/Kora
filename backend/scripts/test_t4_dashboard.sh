#!/usr/bin/env bash
# Smoke test tranche 4 : dashboard summary + score de discipline.
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

# Recupere id Salaire / Nourriture / Loisirs
CATS=$(curl -s "${BASE}/categories" -H "$AUTH")
CAT_SALAIRE=$(echo "$CATS" | python3 -c "import json,sys; print(next(c['id'] for c in json.load(sys.stdin) if c['name']=='Salaire'))")
CAT_NOURRITURE=$(echo "$CATS" | python3 -c "import json,sys; print(next(c['id'] for c in json.load(sys.stdin) if c['name']=='Nourriture'))")
CAT_LOISIRS=$(echo "$CATS" | python3 -c "import json,sys; print(next(c['id'] for c in json.load(sys.stdin) if c['name']=='Loisirs'))")

echo "=== Seed dataset realiste ==="
# revenus
curl -s -o /dev/null -X POST "${BASE}/transactions" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"amount_xof\": 100000, \"kind\": \"income\", \"category_id\": \"${CAT_SALAIRE}\", \"occurred_at\": \"2026-05-05T08:00:00Z\", \"description\": \"Salaire mai\"}"
curl -s -o /dev/null -X POST "${BASE}/transactions" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"amount_xof\": 25000, \"kind\": \"income\", \"category_id\": \"${CAT_SALAIRE}\", \"occurred_at\": \"2026-05-20T08:00:00Z\", \"description\": \"Prime\"}"
# depenses raisonnables
for amt in 2500 3000 4500 1500 1200 3500 2000; do
  curl -s -o /dev/null -X POST "${BASE}/transactions" -H "$AUTH" -H 'Content-Type: application/json' \
    -d "{\"amount_xof\": ${amt}, \"kind\": \"expense\", \"category_id\": \"${CAT_NOURRITURE}\", \"occurred_at\": \"2026-05-15T12:00:00Z\"}"
done
# depenses loisirs (impulsives)
curl -s -o /dev/null -X POST "${BASE}/transactions" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"amount_xof\": 15000, \"kind\": \"expense\", \"category_id\": \"${CAT_LOISIRS}\", \"occurred_at\": \"2026-05-22T20:00:00Z\"}"

# goal partiellement avance
curl -s -o /dev/null -X POST "${BASE}/goals" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"title": "Materiel L3", "target_amount_xof": 80000}'
GOAL_ID=$(curl -s "${BASE}/goals" -H "$AUTH" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])")
curl -s -o /dev/null -X POST "${BASE}/goals/${GOAL_ID}/contribute" -H "$AUTH" -H 'Content-Type: application/json' -d '{"amount_xof": 40000}'

# pot d'epargne
curl -s -o /dev/null -X POST "${BASE}/savings-pots" -H "$AUTH" -H 'Content-Type: application/json' -d '{"name": "Reserve", "initial_balance_xof": 25000}'

echo "ok"
echo

echo "=== GET /dashboard/summary?period_start=2026-05-01&period_end=2026-05-31 ==="
curl -s "${BASE}/dashboard/summary?period_start=2026-05-01&period_end=2026-05-31" -H "$AUTH" | python3 -m json.tool
echo

echo "=== GET /dashboard/score (30 derniers jours = mai) ==="
curl -s "${BASE}/dashboard/score?period_start=2026-05-01&period_end=2026-05-31" -H "$AUTH" | python3 -m json.tool
