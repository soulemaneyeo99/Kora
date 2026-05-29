"""Score de discipline financiere KORA.

Approche : 4 composantes pesees a parts egales, chacune sur 25 pts.

1. TAUX D'EPARGNE (savings_rate)
   = (revenus - depenses) / revenus, sur la periode.
   - >= 30% : 25 pts (top)
   - >= 15% : 18 pts
   - >= 5%  : 12 pts
   - >  0%  : 6 pts
   - <= 0%  : 0 pts

2. REGULARITE DE SUIVI (tracking_regularity)
   Plus l'utilisateur enregistre / ingere de transactions reguliereement, mieux c'est.
   - >= 20 tx/periode : 25 pts
   - >= 10 tx        : 18 pts
   - >= 5 tx         : 12 pts
   - >= 1 tx         : 6 pts
   - 0 tx           : 0 pts

3. PROGRES OBJECTIFS (goal_progress)
   Moyenne de progress_pct sur les goals actifs.
   - >= 75% : 25 pts
   - >= 50% : 18 pts
   - >= 25% : 12 pts
   - >  0%  : 6 pts
   - sinon  : 0 pts (ou 0 si aucun goal)

4. CONTROLE DES DEPENSES IMPULSIVES (impulse_control)
   Ratio (depenses "loisirs" + "Autre depense") / depenses totales.
   - <= 10% : 25 pts
   - <= 20% : 18 pts
   - <= 35% : 12 pts
   - <= 50% : 6 pts
   - > 50%  : 0 pts

Grade : A (>=85), B (>=70), C (>=55), D (>=40), E (<40).
"""
from datetime import date, datetime, time, timezone
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.category import Category
from app.domain.enums import CategoryKind, GoalStatus, TxKind
from app.domain.goal import Goal
from app.domain.transaction import Transaction
from app.schemas.dashboard import DisciplineScore

_IMPULSE_CATEGORIES = {"Loisirs", "Autre depense"}


def _grade(score: int) -> str:
    if score >= 85:
        return "A"
    if score >= 70:
        return "B"
    if score >= 55:
        return "C"
    if score >= 40:
        return "D"
    return "E"


def _bucket(value: float, thresholds: list[tuple[float, int]]) -> int:
    """thresholds = liste de (seuil_min, points) ordonnee du plus haut au plus bas."""
    for threshold, pts in thresholds:
        if value >= threshold:
            return pts
    return 0


async def compute_score(
    db: AsyncSession, *, user_id: UUID, period_start: date, period_end: date
) -> DisciplineScore:
    start = datetime.combine(period_start, time.min, tzinfo=timezone.utc)
    end = datetime.combine(period_end, time.max, tzinfo=timezone.utc)

    # ---- 1. taux d'epargne -------------------------------------------------
    totals_row = (
        await db.execute(
            select(
                func.coalesce(
                    func.sum(
                        case(
                            (Transaction.kind == TxKind.INCOME, Transaction.amount_xof),
                            else_=0,
                        )
                    ),
                    0,
                ).label("income"),
                func.coalesce(
                    func.sum(
                        case(
                            (Transaction.kind == TxKind.EXPENSE, Transaction.amount_xof),
                            else_=0,
                        )
                    ),
                    0,
                ).label("expense"),
                func.count(Transaction.id).label("count"),
            ).where(
                Transaction.user_id == user_id,
                Transaction.occurred_at >= start,
                Transaction.occurred_at <= end,
            )
        )
    ).one()

    income = int(totals_row.income)
    expense = int(totals_row.expense)
    tx_count = int(totals_row.count)

    if income > 0:
        savings_rate = max((income - expense) / income, -1.0)
    else:
        savings_rate = 0.0

    savings_pts = _bucket(
        savings_rate,
        [(0.30, 25), (0.15, 18), (0.05, 12), (0.0001, 6)],
    )

    # ---- 2. regularite de suivi -------------------------------------------
    tracking_pts = _bucket(
        float(tx_count), [(20, 25), (10, 18), (5, 12), (1, 6)]
    )

    # ---- 3. progres objectifs ---------------------------------------------
    goals = (
        await db.execute(
            select(Goal).where(
                Goal.user_id == user_id, Goal.status == GoalStatus.ACTIVE
            )
        )
    ).scalars().all()

    if goals:
        avg_progress = sum(
            min(100.0, 100.0 * g.current_amount_xof / g.target_amount_xof)
            for g in goals
            if g.target_amount_xof > 0
        ) / len(goals)
    else:
        avg_progress = 0.0
    goal_pts = _bucket(avg_progress, [(75, 25), (50, 18), (25, 12), (0.01, 6)])

    # ---- 4. controle depenses impulsives ----------------------------------
    impulse_row = (
        await db.execute(
            select(func.coalesce(func.sum(Transaction.amount_xof), 0))
            .join(Category, Category.id == Transaction.category_id, isouter=True)
            .where(
                Transaction.user_id == user_id,
                Transaction.kind == TxKind.EXPENSE,
                Transaction.occurred_at >= start,
                Transaction.occurred_at <= end,
                Category.kind == CategoryKind.EXPENSE,
                Category.name.in_(_IMPULSE_CATEGORIES),
            )
        )
    ).scalar_one()
    impulse_total = int(impulse_row)
    impulse_ratio = (impulse_total / expense) if expense > 0 else 0.0

    # Plus le ratio est BAS, plus de points. On inverse via 1 - ratio.
    inverted = 1.0 - impulse_ratio
    impulse_pts = _bucket(
        inverted, [(0.90, 25), (0.80, 18), (0.65, 12), (0.50, 6)]
    )

    score = savings_pts + tracking_pts + goal_pts + impulse_pts

    insights = []
    if savings_rate <= 0 and income > 0:
        insights.append(
            "Tu as depense plus que gagne sur la periode. Vise au moins 5% d'epargne."
        )
    elif savings_rate < 0.05 and income > 0:
        insights.append("Ton taux d'epargne est faible. Vise 10% sur la prochaine periode.")
    elif savings_rate >= 0.30:
        insights.append("Excellent taux d'epargne. Continue comme ca !")

    if tx_count < 5:
        insights.append(
            "Suivi tres irregulier : enregistre tes transactions au fil de l'eau."
        )
    elif tx_count >= 20:
        insights.append("Suivi tres regulier, bravo.")

    if not goals:
        insights.append("Aucun objectif actif. Definir un goal aide a tenir le cap.")
    elif avg_progress >= 75:
        insights.append("Tes objectifs sont presque atteints. Tiens bon.")

    if impulse_ratio > 0.35 and expense > 0:
        insights.append(
            f"{int(impulse_ratio * 100)}% de tes depenses sont en categories impulsives."
        )

    return DisciplineScore(
        score=score,
        grade=_grade(score),
        components={
            "savings_rate": savings_pts,
            "tracking_regularity": tracking_pts,
            "goal_progress": goal_pts,
            "impulse_control": impulse_pts,
        },
        period_start=period_start,
        period_end=period_end,
        insights=insights,
    )
