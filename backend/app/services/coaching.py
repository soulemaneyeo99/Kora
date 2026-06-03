"""Coaching personnalise : NextAction + Forecast fin de mois.

Deux primitives 100% deterministes (regles), pas d'IA externe :

- compute_next_action() : 8 regles classees par priorite. La premiere qui
  matche gagne. Le but est qu'il y ait TOUJOURS une action concrete a
  proposer, adaptee a l'etat reel du compte.

- compute_forecast() : extrapolation lineaire des depenses sur le mois
  calendaire en cours. Phrase d'accroche + ton (good/warning/danger).
"""
from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.enums import GoalStatus, TxKind
from app.domain.goal import Goal
from app.domain.transaction import Transaction
from app.schemas.insights import EndOfMonthForecast, NextAction
from app.services.insights import TipSignals, compute_tip_signals


# ---------------------------------------------------------------------------
# Next action
# ---------------------------------------------------------------------------
@dataclass
class _GoalSummary:
    id: UUID
    title: str
    target_xof: int
    current_xof: int
    target_date: date | None

    @property
    def remaining_xof(self) -> int:
        return max(self.target_xof - self.current_xof, 0)

    @property
    def progress_pct(self) -> float:
        if self.target_xof <= 0:
            return 0.0
        return min(100.0, 100.0 * self.current_xof / self.target_xof)


async def _load_active_goals(db: AsyncSession, user_id: UUID) -> list[_GoalSummary]:
    rows = (
        await db.execute(
            select(Goal).where(
                Goal.user_id == user_id, Goal.status == GoalStatus.ACTIVE
            )
        )
    ).scalars().all()
    return [
        _GoalSummary(
            id=g.id,
            title=g.title,
            target_xof=g.target_amount_xof,
            current_xof=g.current_amount_xof,
            target_date=g.target_date,
        )
        for g in rows
    ]


def _round_to_500(amount: int) -> int:
    """Arrondit au 500 FCFA superieur, le plus parlant en CI."""
    if amount <= 0:
        return 0
    return ((amount + 499) // 500) * 500


def _weekly_save_amount(signals: TipSignals) -> int:
    """Suggere un montant hebdomadaire d'epargne raisonnable.

    10% du net mensuel positif, rapporte a la semaine, arrondi a 500 FCFA.
    Borne dure : entre 1 000 et 50 000 FCFA pour rester credible.
    """
    if signals.income_xof <= 0 or signals.savings_rate <= 0:
        return 1000
    net_monthly = int(signals.income_xof * signals.savings_rate)
    weekly = max(int(net_monthly * 0.10 / 4), 1000)
    weekly = min(weekly, 50000)
    return _round_to_500(weekly)


def _catch_up_amount(goal: _GoalSummary, today: date) -> int:
    """Calcule combien il faudrait deposer pour combler le retard d'un goal.

    - Pas de deadline -> 0 (aucun rattrapage temporel calculable).
    - Deadline depassee -> tout ce qui reste (le user est deja en retard).
    - Sinon : rythme hebdomadaire necessaire arrondi a 500 FCFA.
    """
    if goal.target_date is None:
        return 0
    if goal.target_date <= today:
        return goal.remaining_xof
    days_left = (goal.target_date - today).days
    weeks_left = max(days_left / 7, 1)
    weekly_target = int(goal.remaining_xof / weeks_left)
    return _round_to_500(weekly_target)


async def compute_next_action(
    db: AsyncSession, user_id: UUID, today: date | None = None
) -> NextAction:
    """Retourne UNE action concrete recommandee maintenant.

    Regles classees par priorite. La premiere qui matche est retournee.
    Toujours une reponse (fallback "celebrate" / "log_tx").
    """
    today = today or date.today()
    signals = await compute_tip_signals(db, user_id)
    goals = await _load_active_goals(db, user_id)

    # P1 : aucune transaction enregistree
    if signals.tx_count == 0:
        return NextAction(
            code="log_first_tx",
            title="Note ta premiere transaction",
            body="Pour que KORA t'aide vraiment, commence par enregistrer une "
            "depense ou un revenu. Cela prend 20 secondes.",
            cta_label="Ajouter une transaction",
            cta_route="/transactions",
            amount_xof=None,
            priority=1,
        )

    # P1 : pas de goal alors qu'il y a deja du tracking
    if not goals and signals.tx_count >= 5:
        return NextAction(
            code="create_first_goal",
            title="Cree ton premier objectif",
            body="Tu suis bien tes depenses. Donne-toi un cap : un objectif "
            "d'epargne SMART (ex: 50 000 FCFA en 3 mois) change tout.",
            cta_label="Definir un objectif",
            cta_route="/goals",
            amount_xof=None,
            priority=1,
        )

    # P2 : revenu enregistre nul -> pousser a noter les rentrees
    if signals.income_xof == 0 and signals.tx_count > 0:
        return NextAction(
            code="log_income",
            title="N'oublie pas tes revenus",
            body="KORA ne voit que tes depenses. Note tes entrees (salaire, "
            "transferts) pour debloquer le coach et le score d'epargne.",
            cta_label="Ajouter un revenu",
            cta_route="/transactions",
            amount_xof=None,
            priority=2,
        )

    # P2 : depenses impulsives elevees -> proposer une coupe nette
    if signals.impulse_ratio > 0.35 and signals.income_xof > 0:
        # Cible : ramener l'impulse_ratio a 0.20. On coupe (impulse_ratio-0.20)
        # de la depense impulsive. Borne minimum 2 000 FCFA, maximum 30 000.
        expense_monthly = int(
            signals.income_xof * (1 - max(signals.savings_rate, 0))
        )
        impulse_total = int(expense_monthly * signals.impulse_ratio)
        delta = int(impulse_total * (signals.impulse_ratio - 0.20)
                    / signals.impulse_ratio)
        delta = max(2000, min(delta, 30000))
        delta = _round_to_500(delta)
        pct = int(signals.impulse_ratio * 100)
        return NextAction(
            code="trim_impulse",
            title=f"Loisirs et extras : {pct}% de tes depenses",
            body=f"C'est haut. Defi de la semaine : ramene-les a 20% en "
            f"coupant {delta:,} FCFA d'achats non essentiels.".replace(",", " "),
            cta_label="Voir mes depenses",
            cta_route="/transactions",
            amount_xof=delta,
            priority=2,
        )

    # P3 : goal en retard -> proposer un rattrapage
    late_goals = [
        g for g in goals
        if g.target_date is not None
        and g.target_date > today
        and g.progress_pct < _expected_progress_pct(g, today)
    ]
    if late_goals:
        # Prend le plus en retard
        late_goals.sort(
            key=lambda g: _expected_progress_pct(g, today) - g.progress_pct,
            reverse=True,
        )
        g = late_goals[0]
        amount = _catch_up_amount(g, today)
        return NextAction(
            code="catch_up_goal",
            title=f"\"{g.title}\" prend du retard",
            body=f"Tu es a {int(g.progress_pct)}% mais tu devrais etre plus "
            f"avance. Met {amount:,} FCFA cette semaine pour revenir "
            f"dans la cible.".replace(",", " "),
            cta_label=f"Alimenter \"{g.title}\"",
            cta_route="/goals",
            amount_xof=amount,
            priority=3,
        )

    # P3 : goal actif, savings_rate positif -> rythme hebdo
    if goals and signals.savings_rate > 0:
        # Vise le goal le moins avance
        goals.sort(key=lambda g: g.progress_pct)
        g = goals[0]
        amount = _weekly_save_amount(signals)
        return NextAction(
            code="save_weekly",
            title="Ton geste epargne de la semaine",
            body=f"Dimanche, met {amount:,} FCFA dans \"{g.title}\". "
            f"Si tu tiens 4 semaines, tu avances de "
            f"{amount * 4:,} FCFA vers ton objectif.".replace(",", " "),
            cta_label=f"Alimenter \"{g.title}\"",
            cta_route="/goals",
            amount_xof=amount,
            priority=3,
        )

    # P4 : tracking encore irregulier
    if signals.tx_count < 10:
        return NextAction(
            code="log_more_tx",
            title="Continue ton suivi",
            body="Note 1 ou 2 transactions par jour. Au bout de 30 jours, "
            "KORA peut vraiment t'analyser et te conseiller.",
            cta_label="Ajouter une transaction",
            cta_route="/transactions",
            amount_xof=None,
            priority=4,
        )

    # P5 : tout va bien -> celebrer + maintenir
    return NextAction(
        code="celebrate",
        title="Tu es sur le bon rythme",
        body=f"Taux d'epargne {int(signals.savings_rate * 100)}%, suivi "
        "regulier, depenses sous controle. Continue, et augmente "
        "doucement le montant epargne chaque mois.",
        cta_label="Voir mon score",
        cta_route="/dashboard",
        amount_xof=None,
        priority=5,
    )


def _expected_progress_pct(goal: _GoalSummary, today: date) -> float:
    """Progression theorique attendue (lineaire) pour un goal avec deadline.

    Faute de created_at sur _GoalSummary, on utilise une approximation :
    si target_date est dans X jours et la duree typique d'un goal CI est
    ~90 jours, on suppose creation = target_date - 90j. Si la deadline est
    plus proche, on utilise (today - 90j) comme borne basse.
    """
    if goal.target_date is None:
        return 0.0
    assumed_start = goal.target_date.replace().toordinal() - 90
    today_ord = today.toordinal()
    end_ord = goal.target_date.toordinal()
    if end_ord <= assumed_start:
        return 100.0
    elapsed = max(today_ord - assumed_start, 0)
    total = end_ord - assumed_start
    return min(100.0, 100.0 * elapsed / total)


# ---------------------------------------------------------------------------
# Prevision fin de mois
# ---------------------------------------------------------------------------
async def compute_forecast(
    db: AsyncSession, user_id: UUID, today: date | None = None
) -> EndOfMonthForecast:
    today = today or date.today()
    year, month = today.year, today.month
    days_in_month = calendar.monthrange(year, month)[1]
    days_elapsed = today.day
    days_remaining = days_in_month - days_elapsed

    month_start = datetime.combine(date(year, month, 1), time.min, tzinfo=timezone.utc)
    end_dt = datetime.combine(today, time.max, tzinfo=timezone.utc)

    totals = (
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
            ).where(
                Transaction.user_id == user_id,
                Transaction.occurred_at >= month_start,
                Transaction.occurred_at <= end_dt,
            )
        )
    ).one()

    income_so_far = int(totals.income)
    expense_so_far = int(totals.expense)

    if days_elapsed > 0:
        daily_avg = round(expense_so_far / days_elapsed)
        projected_expense = round(expense_so_far * days_in_month / days_elapsed)
    else:
        daily_avg = 0
        projected_expense = 0
    projected_balance = income_so_far - projected_expense

    headline, tone = _forecast_headline(
        income_so_far=income_so_far,
        projected_expense=projected_expense,
        projected_balance=projected_balance,
        days_elapsed=days_elapsed,
        days_in_month=days_in_month,
    )

    return EndOfMonthForecast(
        today=today,
        days_elapsed=days_elapsed,
        days_remaining=days_remaining,
        income_so_far_xof=income_so_far,
        expense_so_far_xof=expense_so_far,
        projected_expense_xof=projected_expense,
        projected_balance_xof=projected_balance,
        daily_avg_expense_xof=daily_avg,
        headline=headline,
        tone=tone,
    )


def _forecast_headline(
    *,
    income_so_far: int,
    projected_expense: int,
    projected_balance: int,
    days_elapsed: int,
    days_in_month: int,
) -> tuple[str, str]:
    """Genere l'accroche et le ton du forecast.

    - Si data insuffisante (debut de mois ou rien depense), retourne "neutral".
    - Sinon, ton selon projected_balance / income.
    """
    if days_elapsed < 3 or projected_expense == 0:
        return ("KORA va t'aider a anticiper ta fin de mois.", "neutral")

    if income_so_far == 0:
        return (
            f"Tu as depense {projected_expense:,} FCFA prevus ce mois. "
            "Ajoute tes revenus pour voir ton solde projete.".replace(",", " "),
            "warning",
        )

    pct_balance = (projected_balance / income_so_far) if income_so_far else 0.0

    if projected_balance < 0:
        deficit = -projected_balance
        return (
            f"A ce rythme, tu finis le mois en deficit de "
            f"{deficit:,} FCFA.".replace(",", " "),
            "danger",
        )
    if pct_balance < 0.05:
        return (
            f"Solde projete : {projected_balance:,} FCFA. Tres serre, "
            "reduis quelques depenses non essentielles.".replace(",", " "),
            "warning",
        )
    if pct_balance >= 0.20:
        return (
            f"Excellent rythme. Tu vas finir le mois avec "
            f"{projected_balance:,} FCFA d'avance, soit "
            f"{int(pct_balance * 100)}% de tes revenus.".replace(",", " "),
            "good",
        )
    return (
        f"Tu finis le mois avec environ {projected_balance:,} FCFA "
        "d'avance. Bonne trajectoire.".replace(",", " "),
        "good",
    )
