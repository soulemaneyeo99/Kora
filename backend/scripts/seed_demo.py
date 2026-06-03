"""Seed d'un compte demo "Awa Kone" pour les demos investisseur.

Idempotent : si le user demo existe, on efface ses tx/goals/pots et on recree.
Les categories systeme ne sont pas touchees.

Usage (local) :
    cd backend && .venv/bin/python -m scripts.seed_demo

Usage (Render shell) :
    python -m scripts.seed_demo

Compte cree :
    phone : +2250700000000  (auto-soumis en AUTH_DEMO_MODE)
    name  : Awa Kone
    bracket : K150_300
    goal : save

Donnees generees (60 derniers jours) :
    - 2 salaires (J-30, J0)
    - depenses quotidiennes realistes (nourriture, transport, telecom)
    - quelques loisirs et imprevus
    - 3 pots d'epargne + 2 goals
"""
from __future__ import annotations

import asyncio
import random
import sys
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

# Permet `python scripts/seed_demo.py` depuis backend/
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import AsyncSessionLocal, engine
from app.domain.category import Category
from app.domain.enums import (
    CategoryKind,
    GoalStatus,
    IncomeBracket,
    PrimaryGoal,
    TxKind,
    TxSource,
)
from app.domain.goal import Goal
from app.domain.savings_pot import SavingsPot
from app.domain.transaction import Transaction
from app.domain.user import User
from app.services.category import seed_default_categories

DEMO_PHONE = "+2250700000000"
DEMO_NAME = "Awa Kone"
DEMO_LOCALE = "fr_CI"

# Graine RNG : meme seed = meme donnees a chaque run, plus pratique pour demo.
RNG_SEED = 20260601


@dataclass(frozen=True)
class TxSpec:
    days_ago: int
    hour: int
    amount: int
    kind: TxKind
    category: str
    description: str
    counterparty: str | None = None


def _build_specs(rng: random.Random) -> list[TxSpec]:
    """Genere ~80 transactions sur les 60 derniers jours.

    Profil "Awa Kone" : enseignante, ~180 000 FCFA / mois, discipline correcte,
    quelques loisirs, un imprevu (sante). Resultat vise :
      - savings_rate ~ 15-20%
      - tracking regulier (1-2 tx / jour)
      - impulse_ratio ~ 15-20%
    """
    specs: list[TxSpec] = []

    # --- Salaires --------------------------------------------------------------
    specs.append(TxSpec(
        days_ago=58, hour=9, amount=180_000, kind=TxKind.INCOME,
        category="Salaire", description="Salaire mensuel",
        counterparty="Etablissement scolaire",
    ))
    specs.append(TxSpec(
        days_ago=28, hour=9, amount=180_000, kind=TxKind.INCOME,
        category="Salaire", description="Salaire mensuel",
        counterparty="Etablissement scolaire",
    ))
    # Petit transfert familial
    specs.append(TxSpec(
        days_ago=45, hour=14, amount=15_000, kind=TxKind.INCOME,
        category="Mobile Money recu", description="Transfert tante",
        counterparty="Tante Aminata",
    ))
    specs.append(TxSpec(
        days_ago=10, hour=18, amount=10_000, kind=TxKind.INCOME,
        category="Vente", description="Vente attieke maison",
    ))

    # --- Nourriture (quotidien) -----------------------------------------------
    food_options = [
        (1_500, "Marche legumes"),
        (2_500, "Riz + sauce"),
        (3_000, "Poisson au four"),
        (1_000, "Petit dej"),
        (4_500, "Marche semaine"),
        (2_000, "Allocation cantine"),
        (800, "Cafe sucre"),
        (5_500, "Courses semaine"),
    ]
    for d in range(0, 60):
        # 1-2 depenses nourriture par jour, sauf 1 jour de pause sur 7
        if d % 7 == 6:
            continue
        n_tx = rng.choice([1, 1, 2])
        for _ in range(n_tx):
            amount, desc = rng.choice(food_options)
            specs.append(TxSpec(
                days_ago=d, hour=rng.randint(8, 20), amount=amount,
                kind=TxKind.EXPENSE, category="Nourriture", description=desc,
            ))

    # --- Transport ------------------------------------------------------------
    for d in range(0, 60):
        # 5 jours / semaine de transport
        if d % 7 in (5, 6):
            continue
        specs.append(TxSpec(
            days_ago=d, hour=7, amount=rng.choice([200, 300, 400, 500]),
            kind=TxKind.EXPENSE, category="Transport",
            description=rng.choice(["Gbaka", "Taxi", "Woro-woro"]),
        ))

    # --- Telecom (recharges) --------------------------------------------------
    for d in (3, 12, 21, 33, 44, 55):
        specs.append(TxSpec(
            days_ago=d, hour=19, amount=rng.choice([1_000, 2_000, 5_000]),
            kind=TxKind.EXPENSE, category="Mobile Money envoye",
            description="Recharge forfait Orange",
        ))

    # --- Loisirs (modere) -----------------------------------------------------
    for d in (5, 14, 23, 31, 40, 48, 56):
        specs.append(TxSpec(
            days_ago=d, hour=20, amount=rng.choice([3_000, 5_000, 8_000, 12_000]),
            kind=TxKind.EXPENSE, category="Loisirs",
            description=rng.choice([
                "Cinema avec Aya", "Sortie restaurant",
                "Maquis", "Anniversaire Yacine",
            ]),
        ))

    # --- Sante (imprevu) -------------------------------------------------------
    specs.append(TxSpec(
        days_ago=22, hour=11, amount=18_500, kind=TxKind.EXPENSE,
        category="Sante", description="Consultation + pharmacie",
    ))

    # --- Vetements -------------------------------------------------------------
    specs.append(TxSpec(
        days_ago=35, hour=16, amount=12_000, kind=TxKind.EXPENSE,
        category="Vetements", description="Pagne Adjame",
    ))

    # --- Education -------------------------------------------------------------
    specs.append(TxSpec(
        days_ago=20, hour=10, amount=15_000, kind=TxKind.EXPENSE,
        category="Education", description="Cours d'anglais en ligne",
    ))

    return specs


async def _wipe_demo_data(db: AsyncSession, user_id) -> None:
    """Efface toutes les donnees du user demo (idempotence)."""
    await db.execute(delete(Transaction).where(Transaction.user_id == user_id))
    await db.execute(delete(Goal).where(Goal.user_id == user_id))
    await db.execute(delete(SavingsPot).where(SavingsPot.user_id == user_id))
    await db.execute(
        delete(Category).where(
            Category.user_id == user_id, Category.is_default.is_(False)
        )
    )
    await db.flush()


async def _ensure_user(db: AsyncSession) -> User:
    user = (
        await db.execute(select(User).where(User.phone_e164 == DEMO_PHONE))
    ).scalar_one_or_none()
    if user is None:
        user = User(
            phone_e164=DEMO_PHONE,
            display_name=DEMO_NAME,
            locale=DEMO_LOCALE,
            income_bracket=IncomeBracket.K150_300,
            primary_goal=PrimaryGoal.SAVE,
        )
        db.add(user)
        await db.flush()
        return user
    user.display_name = DEMO_NAME
    user.locale = DEMO_LOCALE
    user.income_bracket = IncomeBracket.K150_300
    user.primary_goal = PrimaryGoal.SAVE
    await db.flush()
    return user


async def _load_categories_by_name(
    db: AsyncSession,
) -> dict[tuple[str, CategoryKind], Category]:
    rows = (
        await db.execute(
            select(Category).where(Category.user_id.is_(None))
        )
    ).scalars().all()
    return {(c.name, c.kind): c for c in rows}


async def _create_pots(db: AsyncSession, user) -> list[SavingsPot]:
    pots = [
        SavingsPot(
            user_id=user.id, name="Fonds d'urgence", balance_xof=35_000,
            icon="shield", color="#0F6E56",
        ),
        SavingsPot(
            user_id=user.id, name="Voyage Dakar", balance_xof=22_000,
            icon="flight", color="#EF9F27",
        ),
        SavingsPot(
            user_id=user.id, name="Nouveau telephone", balance_xof=8_000,
            icon="smartphone", color="#1D9E75",
        ),
    ]
    for p in pots:
        db.add(p)
    await db.flush()
    return pots


async def _create_goals(db: AsyncSession, user, pots: list[SavingsPot]) -> list[Goal]:
    today = date.today()
    goals = [
        Goal(
            user_id=user.id,
            savings_pot_id=pots[0].id,
            title="Constituer mon fonds d'urgence",
            description="Au moins 1 mois de depenses de cote.",
            target_amount_xof=150_000,
            current_amount_xof=35_000,
            target_date=today + timedelta(days=120),
            status=GoalStatus.ACTIVE,
        ),
        Goal(
            user_id=user.id,
            savings_pot_id=pots[1].id,
            title="Voyage Dakar avec Aya",
            description="Avion + hebergement + extras.",
            target_amount_xof=180_000,
            current_amount_xof=22_000,
            target_date=today + timedelta(days=180),
            status=GoalStatus.ACTIVE,
        ),
    ]
    for g in goals:
        db.add(g)
    await db.flush()
    return goals


async def _insert_transactions(
    db: AsyncSession,
    user,
    specs: list[TxSpec],
    categories: dict[tuple[str, CategoryKind], Category],
) -> int:
    today = datetime.now(timezone.utc)
    inserted = 0
    for s in specs:
        cat_kind = (
            CategoryKind.INCOME if s.kind == TxKind.INCOME else CategoryKind.EXPENSE
        )
        cat = categories.get((s.category, cat_kind))
        when = (
            (today - timedelta(days=s.days_ago))
            .replace(hour=s.hour, minute=0, second=0, microsecond=0)
        )
        db.add(
            Transaction(
                user_id=user.id,
                category_id=cat.id if cat else None,
                amount_xof=s.amount,
                kind=s.kind,
                source=TxSource.MANUAL,
                description=s.description,
                counterparty=s.counterparty,
                occurred_at=when,
            )
        )
        inserted += 1
    await db.flush()
    return inserted


async def _already_seeded(db: AsyncSession) -> bool:
    """True si le user demo existe deja avec >= 10 transactions."""
    user = (
        await db.execute(select(User).where(User.phone_e164 == DEMO_PHONE))
    ).scalar_one_or_none()
    if user is None:
        return False
    tx_count = (
        await db.execute(
            select(func.count(Transaction.id)).where(
                Transaction.user_id == user.id
            )
        )
    ).scalar_one()
    return tx_count >= 10


async def seed_demo(*, force: bool = False) -> dict[str, int | str]:
    """Seed le compte demo. Idempotent : skip si deja fait, sauf force=True."""
    async with AsyncSessionLocal() as db:
        if not force and await _already_seeded(db):
            return {"status": "skipped", "reason": "already seeded"}

        rng = random.Random(RNG_SEED)
        specs = _build_specs(rng)

        await seed_default_categories(db)
        user = await _ensure_user(db)
        await _wipe_demo_data(db, user.id)
        categories = await _load_categories_by_name(db)
        pots = await _create_pots(db, user)
        goals = await _create_goals(db, user, pots)
        inserted = await _insert_transactions(db, user, specs, categories)
        await db.commit()

    return {
        "status": "seeded",
        "phone": DEMO_PHONE,
        "name": DEMO_NAME,
        "transactions": inserted,
        "pots": len(pots),
        "goals": len(goals),
    }


def main() -> None:
    async def _run() -> dict[str, int | str]:
        try:
            return await seed_demo(force=True)
        finally:
            await engine.dispose()

    result = asyncio.run(_run())
    print("=== Demo seed ok ===")
    for k, v in result.items():
        print(f"  {k}: {v}")
    print()
    print(f"Connect with phone {DEMO_PHONE} (mode demo : code 000000).")


if __name__ == "__main__":
    main()
