#!/usr/bin/env bash
# Smoke test tranche 2 : auth -> categories -> transactions -> pots -> goals
set -euo pipefail

PORT="${PORT:-8001}"
BASE="http://localhost:${PORT}/api/v1"
PHONE="${PHONE:-0788776600}"

py() { python3 -c "$1"; }

echo "=== 1. Auth: request + verify ==="
RESP=$(curl -s -X POST "${BASE}/auth/otp/request" \
  -H 'Content-Type: application/json' \
  -d "{\"phone\": \"${PHONE}\"}")
echo "$RESP" | python3 -m json.tool
OTP=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["debug_otp"])')

TOKEN_JSON=$(curl -s -X POST "${BASE}/auth/otp/verify" \
  -H 'Content-Type: application/json' \
  -d "{\"phone\": \"${PHONE}\", \"code\": \"${OTP}\"}")
TOKEN=$(echo "$TOKEN_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
echo ">> JWT recupere (${#TOKEN} chars)"
echo

AUTH="Authorization: Bearer ${TOKEN}"

echo "=== 2. GET /categories (devrait afficher >= 14 systeme) ==="
CATS=$(curl -s "${BASE}/categories" -H "$AUTH")
echo "$CATS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'>> {len(d)} categories')
for c in d[:5]:
    print(f\"  - {c['name']} ({c['kind']}) default={c['is_default']}\")
print('  ...')
"

CAT_NOURRITURE=$(echo "$CATS" | python3 -c "
import json, sys
print(next(c['id'] for c in json.load(sys.stdin) if c['name'] == 'Nourriture'))
")
CAT_SALAIRE=$(echo "$CATS" | python3 -c "
import json, sys
print(next(c['id'] for c in json.load(sys.stdin) if c['name'] == 'Salaire'))
")
echo ">> id Nourriture: $CAT_NOURRITURE"
echo

echo "=== 3. POST /categories (perso) ==="
curl -s -X POST "${BASE}/categories" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name": "Frais ecole UVCI", "kind": "expense", "icon": "school"}' | python3 -m json.tool
echo

echo "=== 4. POST /transactions (depense avec categorie) ==="
TX1=$(curl -s -X POST "${BASE}/transactions" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"amount_xof\": 2500, \"kind\": \"expense\", \"category_id\": \"${CAT_NOURRITURE}\", \"description\": \"Maquis hier soir\", \"occurred_at\": \"2026-05-27T20:30:00Z\"}")
echo "$TX1" | python3 -m json.tool
echo

echo "=== 5. POST /transactions (revenu) ==="
curl -s -X POST "${BASE}/transactions" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"amount_xof\": 75000, \"kind\": \"income\", \"category_id\": \"${CAT_SALAIRE}\", \"description\": \"Stage mai\", \"occurred_at\": \"2026-05-01T08:00:00Z\"}" \
  | python3 -m json.tool
echo

echo "=== 6. POST /transactions avec kind/categorie incoherent (400 attendu) ==="
curl -s -w '\nHTTP %{http_code}\n' -X POST "${BASE}/transactions" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"amount_xof\": 1000, \"kind\": \"income\", \"category_id\": \"${CAT_NOURRITURE}\", \"occurred_at\": \"2026-05-28T10:00:00Z\"}"
echo

echo "=== 7. GET /transactions (liste + total) ==="
curl -s "${BASE}/transactions?limit=10" -H "$AUTH" | python3 -m json.tool
echo

echo "=== 8. POST /savings-pots ==="
POT=$(curl -s -X POST "${BASE}/savings-pots" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name": "Memoire L3", "icon": "school", "initial_balance_xof": 10000}')
echo "$POT" | python3 -m json.tool
POT_ID=$(echo "$POT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
echo

echo "=== 9. POST /savings-pots/{id}/deposit ==="
curl -s -X POST "${BASE}/savings-pots/${POT_ID}/deposit" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"amount_xof": 5000}' | python3 -m json.tool
echo

echo "=== 10. POST /goals (lie au pot) ==="
GOAL=$(curl -s -X POST "${BASE}/goals" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"title\": \"Frais memoire UVCI\", \"target_amount_xof\": 50000, \"savings_pot_id\": \"${POT_ID}\", \"target_date\": \"2026-09-01\"}")
echo "$GOAL" | python3 -m json.tool
echo

echo "=== 11. POST /goals (standalone) + contribute ==="
GOAL2=$(curl -s -X POST "${BASE}/goals" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"title": "Sortie de fin annee", "target_amount_xof": 20000}')
GOAL2_ID=$(echo "$GOAL2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
curl -s -X POST "${BASE}/goals/${GOAL2_ID}/contribute" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"amount_xof": 8000}' | python3 -m json.tool
echo

echo "=== 12. GET /goals ==="
curl -s "${BASE}/goals" -H "$AUTH" | python3 -m json.tool
echo

echo "=== 13. Sans token (401 attendu) ==="
curl -s -w '\nHTTP %{http_code}\n' "${BASE}/transactions"
