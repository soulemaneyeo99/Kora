"""Endpoints notifications : test d'envoi + conseil du jour pousse.

Le conseil du jour cote backend permet a un cron externe (ex: Render cron job
ou un GitHub Action) de declencher la notif quotidienne. Cote mobile, on
prefere les notifs LOCALES (flutter_local_notifications) qui fonctionnent
offline et ne dependent pas de Firebase.
"""
from fastapi import APIRouter

from app.deps import CurrentUserDep, DbDep, NotificationServiceDep
from app.schemas.device import NotificationTestOut
from app.services import insights as insights_svc
from app.services.push_provider import PushMessage

router = APIRouter()


@router.post("/test", response_model=NotificationTestOut)
async def send_test_notification(
    db: DbDep, user: CurrentUserDep, notif: NotificationServiceDep
) -> NotificationTestOut:
    """Envoie une notif de test a tous les devices actifs du user courant.

    Utile pour valider la chaine end-to-end : token enregistre -> provider
    appele -> notif recue. Pratique aussi pour debug en demo client.
    """
    message = PushMessage(
        title="KORA fonctionne 🎉",
        body=f"Salut {user.display_name or 'toi'} ! Tes notifications sont actives.",
        data={"kind": "test"},
    )
    result = await notif.send_to_user(db, user_id=user.id, message=message)
    return NotificationTestOut(
        sent_to_devices=result.sent,
        push_provider=notif.provider_name,
        title=message.title,
        body=message.body,
    )


@router.post("/daily-tip/dispatch", response_model=NotificationTestOut)
async def dispatch_daily_tip(
    db: DbDep, user: CurrentUserDep, notif: NotificationServiceDep
) -> NotificationTestOut:
    """Pousse le conseil du jour de l'user au format push.

    A appeler depuis un job externe (ou depuis l'app au demarrage en
    fallback). Le mobile peut aussi programmer la meme notif en local pour
    eviter la dependance reseau.
    """
    tip = insights_svc.get_tip_of_the_day(user.id)
    message = PushMessage(
        title=f"💡 {tip.title}",
        body=tip.body,
        data={"kind": "daily_tip", "tip_id": str(tip.id)},
    )
    result = await notif.send_to_user(db, user_id=user.id, message=message)
    return NotificationTestOut(
        sent_to_devices=result.sent,
        push_provider=notif.provider_name,
        title=message.title,
        body=message.body,
    )
