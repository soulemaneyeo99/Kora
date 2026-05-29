"""Aggregation des routeurs API v1."""
from fastapi import APIRouter

from app.api.v1 import (
    auth,
    categories,
    dashboard,
    goals,
    health,
    ingest,
    payments,
    savings_pots,
    transactions,
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(categories.router, prefix="/categories", tags=["categories"])
api_router.include_router(
    transactions.router, prefix="/transactions", tags=["transactions"]
)
api_router.include_router(
    ingest.router, prefix="/transactions", tags=["transactions"]
)
api_router.include_router(
    savings_pots.router, prefix="/savings-pots", tags=["savings-pots"]
)
api_router.include_router(goals.router, prefix="/goals", tags=["goals"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
api_router.include_router(payments.router, prefix="/payments", tags=["payments"])
