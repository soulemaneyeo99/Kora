# KORA Backend

Backend FastAPI pour **KORA Finance** — coaching financier comportemental (Côte d'Ivoire).

Backend complet (tranches 1 → 5) : auth OTP, transactions, enveloppes, objectifs,
ingestion notifications mobile money, dashboard avec score de discipline,
commission 0,5% via CinetPay.

## Stack

- **Python 3.12**, FastAPI, SQLAlchemy 2.0 async, Alembic
- **Postgres 16** + **Redis 7** (Docker Compose)
- **Africa's Talking** SMS OTP (mocké en dev)
- **CinetPay** paiement commission (stub Logging en dev)
- 38 tests unitaires pytest

## Quickstart

### 1. Pré-requis

- Docker Desktop (ou Docker Engine natif)
- Python 3.12+
- WSL2 Ubuntu si tu es sur Windows (recommandé)

### 2. Configuration

```bash
cp .env.example .env
# Génère un JWT_SECRET solide :
python3 -c "import secrets; print(secrets.token_hex(32))"
# colle le résultat dans .env → JWT_SECRET=...
```

### 3. Postgres + Redis

```bash
docker compose up -d
```

Ports utilisés : **5433** (Postgres) et **6380** (Redis), pour éviter les conflits
avec d'éventuels services natifs sur 5432 / 6379.

### 4. Venv + deps

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### 5. Migrations

```bash
alembic upgrade head
```

Trois migrations actuellement : `init users` → `categories+transactions+pots+goals` → `payments`.

### 6. Lancer l'API

```bash
uvicorn app.main:app --reload --port 8001
```

Swagger : http://localhost:8001/docs

Au démarrage, l'API seed automatiquement **14 catégories système**
(4 revenus + 10 dépenses) si elles n'existent pas.

### 7. Tester

```bash
# Unitaires
pytest -v

# Smokes end-to-end (uvicorn doit tourner)
bash scripts/test_endpoints.sh           # T1 — auth OTP
PHONE=07$(printf %08d $RANDOM) bash scripts/test_t2.sh             # T2 — CRUD
PHONE=07$(printf %08d $RANDOM) bash scripts/test_t3_ingest.sh      # T3 — ingestion
PHONE=07$(printf %08d $RANDOM) bash scripts/test_t4_dashboard.sh   # T4 — dashboard
PHONE=07$(printf %08d $RANDOM) bash scripts/test_t5_payment.sh     # T5 — commission
```

## Architecture

```
app/
├── main.py                # create_app() + lifespan (seed défauts)
├── config.py              # Settings pydantic-settings (DB/Redis/AT/CinetPay)
├── db.py                  # Engine + session async
├── deps.py                # Toutes les Depends FastAPI
├── core/
│   ├── security.py        # JWT + bcrypt OTP
│   └── phone.py           # Normalisation E.164
├── domain/                # Modèles SQLAlchemy (source de vérité)
│   ├── base.py            # Base + mixins UUID/timestamps
│   ├── enums.py           # TxKind, TxSource, CategoryKind, GoalStatus, PaymentStatus...
│   ├── user.py
│   ├── category.py
│   ├── transaction.py
│   ├── savings_pot.py
│   ├── goal.py
│   └── payment.py
├── schemas/               # DTOs Pydantic (contrats API)
│   ├── auth.py, category.py, transaction.py, savings_pot.py
│   ├── goal.py, dashboard.py, ingestion.py, payment.py
├── services/              # Logique métier
│   ├── otp.py             # OTP + throttle
│   ├── sms_provider.py    # AT + LoggingSmsProvider (dev)
│   ├── category.py        # CRUD + seed défauts
│   ├── transaction.py     # CRUD + idempotence source_ref
│   ├── savings_pot.py     # CRUD + deposit/withdraw
│   ├── goal.py            # CRUD + contribute + sync pot
│   ├── dashboard.py       # Agrégations
│   ├── discipline.py      # Score 0-100 + insights
│   ├── ingestion.py       # Orchestration parser → tx
│   ├── parsers/           # MTN MoMo, Orange Money, Wave (versionnés)
│   ├── payment.py         # Commission KORA
│   └── payment_provider.py # CinetPay + LoggingPaymentProvider (dev)
└── api/v1/                # Routeurs HTTP versionnés
    ├── router.py
    ├── health.py, auth.py
    ├── categories.py, transactions.py
    ├── savings_pots.py, goals.py
    ├── ingest.py, dashboard.py, payments.py
```

### Principes

- **Domain ↔ Schemas** : on n'expose jamais un modèle SQLAlchemy en réponse HTTP. Toujours `Schema.model_validate(orm_obj)`.
- **Services** : la logique métier vit dans `services/`, jamais dans les routeurs.
- **Async first** : tout I/O est `await`able (asyncpg, redis.asyncio, httpx.AsyncClient).
- **Config par injection** : `get_settings()` mis en cache. Aucun `os.environ[...]` ailleurs.
- **Sécurité par défaut** : `DEBUG_OTP=true` refusé si `ENVIRONMENT=production`.

## Endpoints livrés

### Auth
- `POST /api/v1/auth/otp/request` — déclenche un OTP SMS (throttle 60s)
- `POST /api/v1/auth/otp/verify` — vérifie, crée l'utilisateur au besoin, renvoie un JWT

### Catalogue
- `GET/POST /api/v1/categories` — catalogue mixte (système + perso), filtrable par `kind`
- `GET/PATCH/DELETE /api/v1/categories/{id}` — catégories perso uniquement modifiables

### Transactions
- `GET /api/v1/transactions` — liste paginée avec filtres `kind`, `category_id`, `date_from/to`, `source`
- `POST /api/v1/transactions` — création manuelle, valide la cohérence kind/catégorie
- `GET/PATCH/DELETE /api/v1/transactions/{id}`
- `POST /api/v1/transactions/ingest` — **ingestion notification** : route vers le bon parser, dedup via `source_ref`

### Enveloppes
- `GET/POST /api/v1/savings-pots`
- `GET/PATCH/DELETE /api/v1/savings-pots/{id}`
- `POST /api/v1/savings-pots/{id}/deposit` et `/withdraw`

### Objectifs
- `GET/POST /api/v1/goals`
- `GET/PATCH/DELETE /api/v1/goals/{id}`
- `POST /api/v1/goals/{id}/contribute` et `/withdraw` (pour goals standalone)
- Si le goal est lié à un pot, `current_amount_xof` est synchronisé sur le solde du pot

### Dashboard
- `GET /api/v1/dashboard/summary?period_start=YYYY-MM-DD&period_end=...` — totaux période courante vs précédente, top catégories, soldes pots, compteurs goals
- `GET /api/v1/dashboard/score?period_start=...&period_end=...` — score 0-100, grade A-E, composantes (épargne, suivi, progrès, contrôle), insights

### Paiements
- `GET /api/v1/payments/commission/{goal_id}/estimate` — montant commission KORA
- `POST /api/v1/payments/commission/{goal_id}/initiate` — crée le paiement, appelle le provider, renvoie URL de checkout
- `GET /api/v1/payments` et `/{id}` — historique
- `POST /api/v1/payments/webhook/cinetpay` — callback CinetPay (signature HMAC), idempotent

## Pipeline d'ingestion (T3)

```
Notif Android        POST /transactions/ingest
   |                         |
   |  payload                 v
   |  (package_source,    [registry.find]
   |   raw_text,              |
   |   external_id,           v
   |   captured_at)       parser.parse()
                              |
                              v
                       ParsedNotification
                       (montant, kind,
                        counterparty anonymisé,
                        source_ref versionné)
                              |
                              v
                       Idempotence par source_ref
                              |
                              v
                       Transaction persistée
```

Trois parsers livrés (versionnés `v1`) :

| Parser | Sélection | Exemple reconnu |
|---|---|---|
| `mtn_momo` | `package_source` contient `mtn`/`momo`/`mobile money` | "Vous avez recu 5,000 FCFA de +225 07..." |
| `orange_money` | `package_source` contient `orange`/`orangemoney`, ou segment exact `om` | "OM Recu 25000 FCFA de 0707..." |
| `wave` | `package_source` contient `wave` | "Vous avez recu 10 000 FCFA de YEO SOULEYMANE." |

Sélection prioritaire par `parser_hint` explicite.

**Anonymisation** : les numéros de téléphone tiers sont hashés (SHA-256 tronqué)
avant stockage en `counterparty`. Les noms de commerçants sont conservés en clair.

## Score de discipline (T4)

| Composante | Poids | Calcul |
|---|---|---|
| `savings_rate` | 25 pts | (revenus - dépenses) / revenus sur la période |
| `tracking_regularity` | 25 pts | nb de transactions enregistrées |
| `goal_progress` | 25 pts | moyenne progress_pct des goals actifs |
| `impulse_control` | 25 pts | 1 - (dépenses "Loisirs"+"Autre dépense") / total dépenses |

Grade : **A** ≥85, **B** ≥70, **C** ≥55, **D** ≥40, **E** <40.

## Commission KORA (T5)

- **Taux** : `COMMISSION_RATE=0.005` (0,5%)
- **Calcul** : arrondi supérieur (`math.ceil(target * rate)`). 100k FCFA → 500 FCFA, 33k → 167 FCFA.
- **Éligibilité** : `current_amount_xof >= target_amount_xof` OU `status=COMPLETED`.
- **Idempotence** : si un paiement `pending` ou `initiated` existe pour ce goal, on renvoie l'existant. Si `succeeded`, on refuse.
- **Provider** : `CinetPayProvider` si `CINETPAY_API_KEY`+`SITE_ID` configurés, sinon `LoggingPaymentProvider` (dev, ne facture jamais).
- **Webhook** : signature HMAC vérifiée via `X-Signature` (squelette à valider sur doc CinetPay au moment de la mise en prod).

## Sécurité

| Mécanisme | Détail |
|---|---|
| OTP | 6 chiffres, hash bcrypt, TTL 5 min, max 3 essais, throttle 1/min |
| JWT | HS256, TTL 7 jours (`JWT_TTL_HOURS`), type `access` |
| Numéros tiers | hashés SHA-256 (16 hex) dans `counterparty` |
| Texte brut | `raw_text` ingéré stocké uniquement dans la transaction si pertinent (pas de table de logs perma) |
| Secrets | `.env` gitignoré, jamais hardcodés |
| Production | `DEBUG_OTP=true` interdit, `/docs` désactivé, providers en mode réel |
| KORA n'est jamais dépositaire | aucun escrow, paiement direct via CinetPay |

## Roadmap

- ✅ T1 Auth OTP + infra (38/38 tests verts)
- ✅ T2 CRUD complet
- ✅ T3 Ingestion + parsers versionnés
- ✅ T4 Dashboard + score
- ✅ T5 Commission CinetPay
- ⏭️ T6 Mobile Flutter (auth + dashboard + NotificationListener Android via platform channel)
- ⏭️ Cron purge `raw_text` > 7 jours
- ⏭️ Auto-catégorisation ingestion (LLM ou règles)
- ⏭️ iOS (architecture mobile prête)
