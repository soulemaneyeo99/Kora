#!/usr/bin/env bash
# Smoke test tranche 3 : ingestion de notifications mobile money.
set -euo pipefail

PORT="${PORT:-8001}"
BASE="http://localhost:${PORT}/api/v1"
PHONE="${PHONE:-0700${RANDOM}}"

echo "=== Auth ==="
RESP=$(curl -s -X POST "${BASE}/auth/otp/request" -H 'Content-Type: application/json' -d "{\"phone\": \"${PHONE}\"}")
OTP=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["debug_otp"])')
TOKEN=$(curl -s -X POST "${BASE}/auth/otp/verify" -H 'Content-Type: application/json' \
  -d "{\"phone\": \"${PHONE}\", \"code\": \"${OTP}\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
echo ">> JWT ${#TOKEN} chars"
AUTH="Authorization: Bearer ${TOKEN}"
echo

echo "=== 1. Notif MTN MoMo : reception ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.mtn.momo",
  "external_id": "notif-mtn-001",
  "raw_title": "MTN MoMo",
  "raw_text": "Vous avez recu 5,000 FCFA de +225 07 12 34 56 78. Nouveau solde: 12,500 FCFA.",
  "captured_at": "2026-05-28T10:00:00Z"
}' | python3 -m json.tool
echo

echo "=== 2. Meme notif rejoue (dedup attendu) ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.mtn.momo",
  "external_id": "notif-mtn-001",
  "raw_title": "MTN MoMo",
  "raw_text": "Vous avez recu 5,000 FCFA de +225 07 12 34 56 78. Nouveau solde: 12,500 FCFA.",
  "captured_at": "2026-05-28T10:00:00Z"
}' | python3 -m json.tool
echo

echo "=== 3. Notif MTN MoMo : envoi vers commercant ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.mtn.momo",
  "external_id": "notif-mtn-002",
  "raw_text": "Paiement de 1 500 FCFA chez MAQUIS DU CARREFOUR confirme.",
  "captured_at": "2026-05-28T20:30:00Z"
}' | python3 -m json.tool
echo

echo "=== 4. Notif Wave : reception ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.wave.personal",
  "external_id": "wave-001",
  "raw_text": "Vous avez recu 10 000 FCFA de YEO SOULEYMANE.",
  "captured_at": "2026-05-28T11:00:00Z"
}' | python3 -m json.tool
echo

echo "=== 5. Notif Orange Money : paiement ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.orange.om",
  "external_id": "om-001",
  "raw_text": "Vous avez paye 1500 FCFA a SHELL le 27/05/2026",
  "captured_at": "2026-05-27T18:00:00Z"
}' | python3 -m json.tool
echo

echo "=== 6. Notif promo inutile (success=false attendu) ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.mtn.momo",
  "external_id": "promo-1",
  "raw_text": "Offre speciale : 100 Mo gratuits pour 1000 FCFA. Composez *123#",
  "captured_at": "2026-05-28T12:00:00Z"
}' | python3 -m json.tool
echo

echo "=== 7. Package inconnu (no parser) ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.exotic.bank",
  "raw_text": "Vous avez recu 1 000 FCFA",
  "captured_at": "2026-05-28T13:00:00Z"
}' | python3 -m json.tool
echo

echo "=== 8. Hint manuel pour forcer le parser ==="
curl -s -X POST "${BASE}/transactions/ingest" -H "$AUTH" -H 'Content-Type: application/json' -d '{
  "package_source": "com.exotic.bank",
  "parser_hint": "mtn_momo",
  "external_id": "hint-1",
  "raw_text": "Vous avez recu 2 500 FCFA de +225 05 00 00 00 00",
  "captured_at": "2026-05-28T14:00:00Z"
}' | python3 -m json.tool
echo

echo "=== 9. Liste transactions issues de l'ingestion ==="
curl -s "${BASE}/transactions?source=notification&limit=20" -H "$AUTH" | python3 -m json.tool
