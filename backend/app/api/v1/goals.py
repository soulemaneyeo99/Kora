"""Endpoints goals : CRUD + contributions."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from fastapi import status as http_status

from app.deps import CurrentUserDep, DbDep
from app.domain.enums import GoalStatus
from app.schemas.goal import GoalContribution, GoalCreate, GoalOut, GoalUpdate
from app.services import goal as svc

router = APIRouter()


@router.get("", response_model=list[GoalOut])
async def list_goals(
    db: DbDep,
    user: CurrentUserDep,
    status: GoalStatus | None = Query(default=None),
) -> list[GoalOut]:
    goals = await svc.list_for_user(db, user_id=user.id, status=status)
    return [GoalOut.model_validate(g) for g in goals]


@router.post("", response_model=GoalOut, status_code=http_status.HTTP_201_CREATED)
async def create_goal(
    payload: GoalCreate, db: DbDep, user: CurrentUserDep
) -> GoalOut:
    try:
        goal = await svc.create_for_user(db, user_id=user.id, payload=payload)
    except svc.GoalLinkedPotInvalid as e:
        raise HTTPException(http_status.HTTP_400_BAD_REQUEST, str(e)) from e
    return GoalOut.model_validate(goal)


@router.get("/{goal_id}", response_model=GoalOut)
async def get_goal(
    goal_id: UUID, db: DbDep, user: CurrentUserDep
) -> GoalOut:
    try:
        goal = await svc.get_for_user(db, user_id=user.id, goal_id=goal_id)
    except svc.GoalNotFound as e:
        raise HTTPException(http_status.HTTP_404_NOT_FOUND, str(e)) from e
    return GoalOut.model_validate(goal)


@router.patch("/{goal_id}", response_model=GoalOut)
async def update_goal(
    goal_id: UUID,
    payload: GoalUpdate,
    db: DbDep,
    user: CurrentUserDep,
) -> GoalOut:
    try:
        goal = await svc.update_for_user(
            db, user_id=user.id, goal_id=goal_id, payload=payload
        )
    except svc.GoalNotFound as e:
        raise HTTPException(http_status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.GoalLinkedPotInvalid as e:
        raise HTTPException(http_status.HTTP_400_BAD_REQUEST, str(e)) from e
    except svc.GoalNotEditable as e:
        raise HTTPException(http_status.HTTP_409_CONFLICT, str(e)) from e
    return GoalOut.model_validate(goal)


@router.delete("/{goal_id}", status_code=http_status.HTTP_204_NO_CONTENT)
async def delete_goal(goal_id: UUID, db: DbDep, user: CurrentUserDep) -> None:
    try:
        await svc.delete_for_user(db, user_id=user.id, goal_id=goal_id)
    except svc.GoalNotFound as e:
        raise HTTPException(http_status.HTTP_404_NOT_FOUND, str(e)) from e


@router.post("/{goal_id}/contribute", response_model=GoalOut)
async def contribute(
    goal_id: UUID,
    payload: GoalContribution,
    db: DbDep,
    user: CurrentUserDep,
) -> GoalOut:
    try:
        goal = await svc.contribute(
            db, user_id=user.id, goal_id=goal_id, amount_xof=payload.amount_xof
        )
    except svc.GoalNotFound as e:
        raise HTTPException(http_status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.GoalNotEditable as e:
        raise HTTPException(http_status.HTTP_409_CONFLICT, str(e)) from e
    return GoalOut.model_validate(goal)


@router.post("/{goal_id}/withdraw", response_model=GoalOut)
async def withdraw(
    goal_id: UUID,
    payload: GoalContribution,
    db: DbDep,
    user: CurrentUserDep,
) -> GoalOut:
    try:
        goal = await svc.withdraw(
            db, user_id=user.id, goal_id=goal_id, amount_xof=payload.amount_xof
        )
    except svc.GoalNotFound as e:
        raise HTTPException(http_status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.GoalNotEditable as e:
        raise HTTPException(http_status.HTTP_409_CONFLICT, str(e)) from e
    return GoalOut.model_validate(goal)
