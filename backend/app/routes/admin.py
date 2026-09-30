from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.admin import (
    AdminSummary,
    AdminTaskResponse,
    AdminTaskStatusUpdate,
    AdminUserResponse,
)
from app.services import admin_service
from app.utils.security import get_admin_user

router = APIRouter()


@router.get("/summary", response_model=AdminSummary)
def get_summary(
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_admin_user),
):
    return admin_service.get_admin_summary(db)


@router.get("/users", response_model=list[AdminUserResponse])
def get_users(
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_admin_user),
):
    return admin_service.list_users(db)


@router.delete("/users/{user_id}", status_code=status.HTTP_200_OK)
def remove_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_admin_user),
):
    try:
        deleted = admin_service.delete_user(db, user_id, current_admin)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return {"message": "User deleted successfully"}


@router.get("/tasks", response_model=list[AdminTaskResponse])
def get_tasks(
    search: Optional[str] = Query(default=None),
    status_filter: Optional[str] = Query(default=None, alias="status"),
    user_id: Optional[int] = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_admin_user),
):
    return admin_service.list_tasks(
        db,
        search=search,
        status_filter=status_filter,
        user_id=user_id,
    )


@router.patch("/tasks/{task_id}/status", response_model=AdminTaskResponse)
def change_task_status(
    task_id: int,
    payload: AdminTaskStatusUpdate,
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_admin_user),
):
    task = admin_service.update_task_status(db, task_id, payload.status)
    if task is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    return task


@router.delete("/tasks/{task_id}", status_code=status.HTTP_200_OK)
def remove_task(
    task_id: int,
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_admin_user),
):
    deleted = admin_service.delete_task(db, task_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    return {"message": "Task deleted successfully"}
