"""Re-export des modeles pour Alembic autogenerate.

Tout nouveau modele doit etre importe ici pour que `alembic revision --autogenerate`
le detecte dans Base.metadata.
"""
from app.domain.base import Base
from app.domain.category import Category
from app.domain.device_token import DeviceToken
from app.domain.enums import (
    CategoryKind,
    DevicePlatform,
    GoalStatus,
    PaymentProvider,
    PaymentStatus,
    TxKind,
    TxSource,
)
from app.domain.goal import Goal
from app.domain.payment import Payment
from app.domain.savings_pot import SavingsPot
from app.domain.transaction import Transaction
from app.domain.user import User

__all__ = [
    "Base",
    "Category",
    "CategoryKind",
    "DevicePlatform",
    "DeviceToken",
    "Goal",
    "GoalStatus",
    "Payment",
    "PaymentProvider",
    "PaymentStatus",
    "SavingsPot",
    "Transaction",
    "TxKind",
    "TxSource",
    "User",
]
