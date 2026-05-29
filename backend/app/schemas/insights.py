"""Schemas insights : conseil du jour, badges (CDC F11, F19)."""
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
