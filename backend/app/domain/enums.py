"""Enums partages des modeles domaine."""
from enum import Enum


class TxKind(str, Enum):
    """Sens du mouvement d'argent."""

    INCOME = "income"
    EXPENSE = "expense"
    TRANSFER = "transfer"


class TxSource(str, Enum):
    """Origine technique de la transaction."""

    MANUAL = "manual"
    NOTIFICATION = "notification"
    SMS = "sms"
    MOBILE_MONEY_API = "mobile_money_api"
    BANK_API = "bank_api"


class CategoryKind(str, Enum):
    """Categorie de revenu ou de depense."""

    INCOME = "income"
    EXPENSE = "expense"


class GoalStatus(str, Enum):
    """Etat d'un objectif financier."""

    ACTIVE = "active"
    COMPLETED = "completed"
    ABANDONED = "abandoned"


class PaymentStatus(str, Enum):
    """Etat d'un paiement de commission."""

    PENDING = "pending"        # cree, en attente d'init provider
    INITIATED = "initiated"    # provider a renvoye une URL/transaction id
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLED = "cancelled"


class PaymentProvider(str, Enum):
    """Provider de paiement utilise."""

    CINETPAY = "cinetpay"
    LOGGING = "logging"  # dev only, ne facture jamais


class IncomeBracket(str, Enum):
    """Tranche de revenus mensuels declaree (CDC F02)."""

    UNDER_80K = "under_80k"        # < 80 000 FCFA
    K80_150 = "k80_150"            # 80-150k
    K150_300 = "k150_300"          # 150-300k
    OVER_300K = "over_300k"        # 300k+


class PrimaryGoal(str, Enum):
    """Objectif principal declare a l'onboarding (CDC F02)."""

    SAVE = "save"                  # Epargner
    PAY_BILLS = "pay_bills"        # Payer factures
    BUY = "buy"                    # Acheter
    BUSINESS = "business"          # Business


class DevicePlatform(str, Enum):
    """Plateforme du device pour les push notifications."""

    ANDROID = "android"
    IOS = "ios"
    WEB = "web"
