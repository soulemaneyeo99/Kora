"""Schemas insights : conseil du jour, badges, prochaine action, prevision."""
from datetime import date

from pydantic import BaseModel


class DailyTip(BaseModel):
    """Conseil du jour personnalise selon le contexte utilisateur."""

    id: int                # 0..N-1, index dans la bibliotheque locale
    title: str             # accroche courte
    body: str              # 1-2 phrases actionnables
    category: str          # discipline | epargne | depenses | revenus | objectifs


class Badge(BaseModel):
    """Badge gamification (CDC F19, 8 badges Phase 1)."""

    code: str              # cle stable, ex: "first_step"
    title: str             # label affiche
    description: str       # condition d'obtention
    emoji: str             # icone unique
    earned: bool           # true si l'utilisateur l'a debloque
    progress_label: str | None = None  # ex: "5 / 7 jours" si en cours


class NextAction(BaseModel):
    """Prochaine action recommandee par KORA, personnalisee.

    Une seule carte affichee a la fois. La regle est deterministe : on
    classe les regles candidates par priorite et on retourne la premiere
    qui s'applique.
    """

    code: str              # cle stable, ex: "save_weekly", "log_first_tx"
    title: str             # accroche (1 ligne)
    body: str              # 1-2 phrases d'explication
    cta_label: str         # bouton, ex: "Mettre 3 000 FCFA de cote"
    cta_route: str         # route mobile, ex: "/goals", "/transactions/new"
    amount_xof: int | None = None  # montant suggere si pertinent
    priority: int          # 1 (urgent) -> 5 (info)


class EndOfMonthForecast(BaseModel):
    """Prevision de fin de mois basee sur le rythme observe.

    Linear : (depenses cumulees / jours ecoules) * jours restants + cumul.
    Simple, robuste, comprehensible. Pas de ML.
    """

    today: date
    days_elapsed: int      # depuis le 1er du mois (1..31)
    days_remaining: int    # jusqu'a fin de mois
    income_so_far_xof: int
    expense_so_far_xof: int
    projected_expense_xof: int  # extrapolation lineaire fin de mois
    projected_balance_xof: int  # income_so_far - projected_expense
    daily_avg_expense_xof: int  # moyenne par jour ecoule
    headline: str          # phrase d'accroche, ex: "A ce rythme, tu finis a -12 000 FCFA"
    tone: str              # "good" | "warning" | "danger" | "neutral"
