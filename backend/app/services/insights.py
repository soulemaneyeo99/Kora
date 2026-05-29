"""Service insights : conseil du jour + badges (CDC F11, F19).

Conseils du jour : bibliotheque locale de 30 conseils localises Cote d'Ivoire.
Selection deterministe = hash(user_id + date_iso) % len. Pas d'aleatoire pur
pour que le meme conseil reste afficher toute la journee, et qu'il change
chaque jour de maniere previsible.

Badges : 8 badges Phase 1 calcules a la volee depuis les transactions, goals
et le score discipline. Pas de table dediee : pas besoin de migration, et
les conditions evoluent vite en debut de produit.
"""
import hashlib
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.enums import GoalStatus, TxKind
from app.domain.goal import Goal
from app.domain.transaction import Transaction
from app.schemas.insights import Badge, DailyTip
from app.services import discipline as discipline_svc

# ---------------------------------------------------------------------------
# Bibliotheque de 30 conseils CI (localises, ton coach bienveillant)
# ---------------------------------------------------------------------------
_TIPS: list[dict[str, str]] = [
    # discipline / suivi (10)
    {"title": "Note tes depenses chaque soir",
     "body": "5 min le soir, tu repasses la journee. C'est la regle d'or des gens "
             "qui sortent de la galere financiere.",
     "category": "discipline"},
    {"title": "Le carnet bat la memoire",
     "body": "Tu crois te souvenir de tes depenses. Tu sous-estimes toujours de "
             "20%. C'est pour ca que KORA existe.",
     "category": "discipline"},
    {"title": "Une depense, une categorie",
     "body": "Range chaque sortie immediatement. Sinon a la fin du mois tu ne "
             "sais plus ou est partie ta moitie d'argent.",
     "category": "discipline"},
    {"title": "Les petits achats tuent",
     "body": "100 FCFA x 30 jours = 3 000 FCFA. Le cafe quotidien, c'est ton "
             "abonnement Netflix invisible.",
     "category": "discipline"},
    {"title": "Garde les recus 24h",
     "body": "Meme un recu de boutique. Ca t'aide a verifier KORA en cas de "
             "doute. Apres tu peux jeter.",
     "category": "discipline"},
    {"title": "Le dimanche soir, bilan",
     "body": "10 min chaque dimanche : combien je gagne, combien je depense, "
             "combien il reste. Ca change ta semaine.",
     "category": "discipline"},
    {"title": "Mesure avant d'optimiser",
     "body": "Tu ne peux pas reduire ce que tu n'as pas mesure. Premier mois : "
             "tu observes. Deuxieme mois : tu coupes.",
     "category": "discipline"},
    {"title": "Pas de jour zero",
     "body": "Meme les jours sans depense, ouvre KORA 30 secondes. La "
             "discipline naissait dans la repetition.",
     "category": "discipline"},
    {"title": "L'argent aime la lumiere",
     "body": "Quand tu vois clairement ou il va, tu prends de meilleures "
             "decisions. L'opacite, c'est ton ennemi.",
     "category": "discipline"},
    {"title": "Ton score augmente lentement",
     "body": "Pas de raccourci. Le score de discipline reflete 30 jours de "
             "comportement. Patience.",
     "category": "discipline"},
    # epargne (8)
    {"title": "Paie-toi en premier",
     "body": "Des que tu recois ton argent, mets de cote AVANT de depenser. "
             "Meme 1 000 FCFA. La regle qui change tout.",
     "category": "epargne"},
    {"title": "10% systematique",
     "body": "10% de chaque revenu va dans un pot epargne. Sans negocier avec "
             "toi-meme. Au bout d'un an, tu as 1,2 mois de revenus de cote.",
     "category": "epargne"},
    {"title": "Le fonds d'urgence d'abord",
     "body": "Avant d'epargner pour un projet, monte 1 mois de depenses en "
             "cas de coup dur. C'est ton parachute.",
     "category": "epargne"},
    {"title": "Petits pots, gros impact",
     "body": "Plusieurs petits pots (transport, sante, projet) > un seul gros. "
             "Tu visualises mieux, tu sais mieux ou tu en es.",
     "category": "epargne"},
    {"title": "Cache l'argent de toi-meme",
     "body": "Ce qui est facile a sortir part facile. Mets ton epargne sur un "
             "compte different, ou un pot KORA bloque.",
     "category": "epargne"},
    {"title": "Defi 30 jours sans achat impulsif",
     "body": "Tente : 30 jours, aucun achat non prevu. Si tu hesites, tu "
             "attends 48h. Tu seras surpris du resultat.",
     "category": "epargne"},
    {"title": "Tontine + KORA",
     "body": "Ta tontine reste un super outil social. Mais utilise KORA pour "
             "suivre quand tu cotises et quand tu touches.",
     "category": "epargne"},
    {"title": "L'epargne n'est pas le reste",
     "body": "Si tu epargnes ce qui reste a la fin du mois, il ne restera "
             "rien. Inverse la formule.",
     "category": "epargne"},
    # depenses (6)
    {"title": "La regle des 24h",
     "body": "Achat non essentiel > 5 000 FCFA ? Attends 24h. Si tu y penses "
             "encore demain, achete. Sinon, oublie.",
     "category": "depenses"},
    {"title": "Liste avant le marche",
     "body": "Tu rentres au marche avec une liste, tu en sors avec ce qui est "
             "dessus. Sans liste, tu depenses 30% de plus.",
     "category": "depenses"},
    {"title": "Frais cachees du mobile money",
     "body": "Verifie les frais sur chaque transfert. 1% par-ci, 50 FCFA "
             "par-la, ca fait des milliers a la fin du mois.",
     "category": "depenses"},
    {"title": "Le credit telephone",
     "body": "Un forfait illimite peut couter moins cher que tes recharges "
             "quotidiennes. Calcule, tu seras surpris.",
     "category": "depenses"},
    {"title": "Cuisine maison = argent gagne",
     "body": "Un plat maison coute 3 a 5 fois moins qu'un plat dehors. "
             "Cuisine 2 jours d'avance, tu gagnes des dizaines de milliers.",
     "category": "depenses"},
    {"title": "Top 3 categories",
     "body": "Va dans l'onglet Analyse : tes 3 plus grosses categories de "
             "depense, c'est la que tu peux gagner de l'argent.",
     "category": "depenses"},
    # revenus (3)
    {"title": "Diversifie tes revenus",
     "body": "Un seul revenu = fragile. Petite activite cote, transferts "
             "familiaux, freelance : 2 sources minimum.",
     "category": "revenus"},
    {"title": "Augmente tes prix avant tes ventes",
     "body": "Avant de chercher 10 nouveaux clients, augmente de 10% tes "
             "anciens. Souvent plus facile, meme effet.",
     "category": "revenus"},
    {"title": "Garde une trace de chaque entree",
     "body": "Surtout les revenus en especes. Sans trace, tu sous-estimes "
             "ton vrai pouvoir d'achat et tu te demotive.",
     "category": "revenus"},
    # objectifs (3)
    {"title": "Un objectif SMART",
     "body": "Specifique, Mesurable, Atteignable, Realiste, Temporel. "
             "\"Epargner\" ne marche pas. \"50 000 FCFA en 3 mois\" oui.",
     "category": "objectifs"},
    {"title": "Decoupe en mini-jalons",
     "body": "Un objectif de 100 000 FCFA, c'est 8 333 par mois ou 277 par "
             "jour. Le decoupage rend possible l'impossible.",
     "category": "objectifs"},
    {"title": "Celebre les jalons",
     "body": "Atteint 25% d'un objectif ? Note-le, partage-le. Le cerveau a "
             "besoin de petites victoires pour tenir.",
     "category": "objectifs"},
]


def get_tip_of_the_day(user_id: UUID, today: date | None = None) -> DailyTip:
    """Renvoie le conseil du jour pour cet utilisateur.

    Selection deterministe : SHA-256(user_id + date_iso) % len(_TIPS).
    Garantit : meme conseil toute la journee, change demain, varie par user.
    """
    today = today or date.today()
    key = f"{user_id}-{today.isoformat()}".encode()
    digest = hashlib.sha256(key).digest()
    idx = int.from_bytes(digest[:4], "big") % len(_TIPS)
    raw = _TIPS[idx]
    return DailyTip(
        id=idx,
        title=raw["title"],
        body=raw["body"],
        category=raw["category"],
    )


# ---------------------------------------------------------------------------
# Badges (8 badges Phase 1)
# ---------------------------------------------------------------------------
async def compute_badges(db: AsyncSession, user_id: UUID) -> list[Badge]:
    """Calcule l'etat des 8 badges depuis l'etat actuel des donnees."""
    # Comptages
    tx_count = (await db.execute(
        select(func.count(Transaction.id)).where(Transaction.user_id == user_id)
    )).scalar() or 0

    income_count = (await db.execute(
        select(func.count(Transaction.id)).where(
            Transaction.user_id == user_id,
            Transaction.kind == TxKind.INCOME,
        )
    )).scalar() or 0

    expense_count = (await db.execute(
        select(func.count(Transaction.id)).where(
            Transaction.user_id == user_id,
            Transaction.kind == TxKind.EXPENSE,
        )
    )).scalar() or 0

    # Streak journalier : jours distincts avec transaction, derniere semaine
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    distinct_days_7 = (await db.execute(
        select(func.count(func.distinct(func.date(Transaction.occurred_at)))).where(
            Transaction.user_id == user_id,
            Transaction.occurred_at >= seven_days_ago,
        )
    )).scalar() or 0

    thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)
    distinct_days_30 = (await db.execute(
        select(func.count(func.distinct(func.date(Transaction.occurred_at)))).where(
            Transaction.user_id == user_id,
            Transaction.occurred_at >= thirty_days_ago,
        )
    )).scalar() or 0

    # Goals
    active_goals = (await db.execute(
        select(func.count(Goal.id)).where(
            Goal.user_id == user_id, Goal.status == GoalStatus.ACTIVE
        )
    )).scalar() or 0

    completed_goals = (await db.execute(
        select(func.count(Goal.id)).where(
            Goal.user_id == user_id, Goal.status == GoalStatus.COMPLETED
        )
    )).scalar() or 0

    # Score discipline (30j roulants)
    try:
        score_obj = await discipline_svc.compute_score(
            db,
            user_id=user_id,
            period_start=date.today() - timedelta(days=30),
            period_end=date.today(),
        )
        score_value = score_obj.score
    except Exception:
        score_value = 0

    return [
        Badge(
            code="first_step",
            title="Premier pas",
            description="Enregistrer ta premiere transaction.",
            emoji="🌱",
            earned=tx_count >= 1,
            progress_label=None if tx_count >= 1 else "0 / 1",
        ),
        Badge(
            code="ten_tx",
            title="Suiveur",
            description="10 transactions enregistrees.",
            emoji="📋",
            earned=tx_count >= 10,
            progress_label=None if tx_count >= 10 else f"{tx_count} / 10",
        ),
        Badge(
            code="week_streak",
            title="Semaine en or",
            description="Au moins une transaction sur 5 jours differents en 7 jours.",
            emoji="🔥",
            earned=distinct_days_7 >= 5,
            progress_label=None if distinct_days_7 >= 5 else f"{distinct_days_7} / 5",
        ),
        Badge(
            code="month_streak",
            title="Endurance",
            description="Active sur 20 jours differents en 30 jours.",
            emoji="💪",
            earned=distinct_days_30 >= 20,
            progress_label=None if distinct_days_30 >= 20 else f"{distinct_days_30} / 20",
        ),
        Badge(
            code="first_goal",
            title="Visionnaire",
            description="Creer ton premier objectif d'epargne.",
            emoji="🎯",
            earned=(active_goals + completed_goals) >= 1,
            progress_label=None if (active_goals + completed_goals) >= 1 else "0 / 1",
        ),
        Badge(
            code="goal_reached",
            title="Champion",
            description="Atteindre un objectif d'epargne.",
            emoji="🏆",
            earned=completed_goals >= 1,
            progress_label=None if completed_goals >= 1 else "0 / 1",
        ),
        Badge(
            code="balanced",
            title="Equilibriste",
            description="Au moins une entree ET une depense enregistrees.",
            emoji="⚖️",
            earned=income_count >= 1 and expense_count >= 1,
            progress_label=None if (income_count >= 1 and expense_count >= 1)
            else f"{min(income_count, 1)} / 1 entree, {min(expense_count, 1)} / 1 sortie",
        ),
        Badge(
            code="disciplined",
            title="Discipline",
            description="Score de discipline >= 70 sur 30 jours.",
            emoji="🌟",
            earned=score_value >= 70,
            progress_label=None if score_value >= 70 else f"{score_value} / 70",
        ),
    ]
