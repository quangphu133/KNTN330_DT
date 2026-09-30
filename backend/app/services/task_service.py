from typing import Any, Dict, List, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.task import Task
from app.models.user import User


def create_task(
    db: Session,
    user: User,
    title: str,
    description: Optional[str],
    priority: str,
    due_date,
    status: str,
) -> Task:
    task = Task(
        title=title,
        description=description,
        priority=priority,
        due_date=due_date,
        status=status,
        user_id=user.id,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def get_tasks(
    db: Session,
    user: User,
    search: Optional[str] = None,
    status_filter: Optional[str] = None,
) -> List[Task]:
    query = db.query(Task).filter(Task.user_id == user.id)

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                Task.title.ilike(pattern),
                Task.description.ilike(pattern),
            )
        )

    if status_filter:
        query = query.filter(Task.status == status_filter)

    return query.order_by(Task.due_date.asc(), Task.id.desc()).all()


def update_task(
    db: Session,
    user: User,
    task_id: int,
    updates: Dict[str, Any],
) -> Optional[Task]:
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == user.id).first()
    if task is None:
        return None

    for field, value in updates.items():
        setattr(task, field, value)

    db.commit()
    db.refresh(task)
    return task


def delete_task(db: Session, user: User, task_id: int) -> bool:
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == user.id).first()
    if task is None:
        return False

    db.delete(task)
    db.commit()
    return True
