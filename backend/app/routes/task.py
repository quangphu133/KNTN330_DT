from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.task import TaskCreate, TaskResponse, TaskUpdate
from app.services.task_service import (
    create_task,
    delete_task,
    get_tasks,
    update_task,
)
from app.utils.security import get_current_user

router = APIRouter()


@router.get("", response_model=list[TaskResponse])
def list_tasks(
    search: Optional[str] = Query(default=None),
    status_filter: Optional[str] = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_tasks(db, current_user, search=search, status_filter=status_filter)


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
def create_new_task(
    payload: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_task(
        db,
        current_user,
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        due_date=payload.due_date,
        status=payload.status,
    )


@router.put("/{task_id}", response_model=TaskResponse)
def edit_task(
    task_id: int,
    payload: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    updated_task = update_task(
        db,
        current_user,
        task_id=task_id,
        updates=payload.model_dump(exclude_unset=True),
    )
    if updated_task is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    return updated_task


@router.delete("/{task_id}", status_code=status.HTTP_200_OK)
def remove_task(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    deleted = delete_task(db, current_user, task_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    return {"message": "Task deleted successfully"}
