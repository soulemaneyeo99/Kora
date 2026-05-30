"""Authentification par OTP SMS.

Flux :
  1. POST /auth/otp/request {phone}    -> SMS envoye, throttle 60s
  2. POST /auth/otp/verify  {phone, code} -> JWT + cree user au besoin
"""
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.phone import InvalidPhoneError, normalize_to_e164
from app.core.security import create_access_token
from app.deps import DbDep, OtpServiceDep
from app.domain.user import User
from app.schemas.auth import (
    OTPRequestIn,
    OTPRequestOut,
    OTPVerifyIn,
    TokenOut,
    UserPublic,
)
from app.services.otp import (
    OtpExhausted,
    OtpInvalid,
    OtpNotFound,
    OtpThrottled,
)

router = APIRouter()


def _normalize_or_400(raw: str) -> str:
    try:
        return normalize_to_e164(raw)
    except InvalidPhoneError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e)) from e


@router.post(
    "/otp/request",
    response_model=OTPRequestOut,
    status_code=status.HTTP_202_ACCEPTED,
)
async def request_otp(
    payload: OTPRequestIn, otp_service: OtpServiceDep
) -> OTPRequestOut:
    phone = _normalize_or_400(payload.phone)
    try:
        result = await otp_service.issue(phone_e164=phone)
    except OtpThrottled as e:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, str(e)) from e
    return OTPRequestOut(
        message=(
            "Mode demo : utilisez le code 000000 (ou n'importe quel code 4-6 chiffres)"
            if otp_service.demo_mode
            else "Code envoye par SMS"
        ),
        expires_in_seconds=result.expires_in_seconds,
        debug_otp=result.debug_code,
        demo_mode=otp_service.demo_mode,
    )


@router.post("/otp/verify", response_model=TokenOut)
async def verify_otp(
    payload: OTPVerifyIn, db: DbDep, otp_service: OtpServiceDep
) -> TokenOut:
    phone = _normalize_or_400(payload.phone)
    try:
        await otp_service.verify(phone_e164=phone, code=payload.code)
    except OtpNotFound as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e)) from e
    except OtpInvalid as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e)) from e
    except OtpExhausted as e:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, str(e)) from e

    user = (
        await db.execute(select(User).where(User.phone_e164 == phone))
    ).scalar_one_or_none()
    if user is None:
        user = User(phone_e164=phone)
        db.add(user)
        await db.flush()

    user.last_login_at = datetime.now(timezone.utc)
    await db.flush()

    token, expires_at = create_access_token(user.id)
    return TokenOut(
        access_token=token,
        expires_at=expires_at,
        user=UserPublic.model_validate(user),
    )
