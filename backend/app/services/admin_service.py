from typing import Optional

from sqlalchemy import case, func, or_
from sqlalchemy.orm import Session, joinedload

from app.models.task import Task
from app.models.user import User
from app.schemas.admin import AdminSummary


def get_admin_summary(db: Session) -> AdminSummary:
    total_users = db.query(func.count(User.id)).scalar() or 0
    admin_users = db.query(func.count(User.id)).filter(User.is_admin.is_(True)).scalar() or 0

    task_totals = db.query(
        func.count(Task.id),
        func.sum(case((Task.status == "pending", 1), else_=0)),
        func.sum(case((Task.status == "in_progress", 1), else_=0)),
        func.sum(case((Task.status == "completed", 1), else_=0)),
    ).one()

    return AdminSummary(
        total_users=total_users,
        total_tasks=task_totals[0] or 0,
        pending_tasks=task_totals[1] or 0,
        in_progress_tasks=task_totals[2] or 0,
        completed_tasks=task_totals[3] or 0,
        admin_users=admin_users,
    )


def list_users(db: Session):
    rows = (
        db.query(
            User.id,
            User.name,
            User.email,
            User.is_admin,
            func.count(Task.id).label("task_count"),
        )
        .outerjoin(Task, Task.user_id == User.id)
        .group_by(User.id, User.name, User.email, User.is_admin)
        .order_by(User.is_admin.desc(), User.name.asc(), User.id.asc())
        .all()
    )

    return [
        {
            "id": row.id,
            "name": row.name,
            "email": row.email,
            "is_admin": bool(row.is_admin),
            "task_count": row.task_count,
        }
        for row in rows
    ]


def list_tasks(
    db: Session,
    search: Optional[str] = None,
    status_filter: Optional[str] = None,
    user_id: Optional[int] = None,
):
    query = db.query(Task).options(joinedload(Task.user))

    if search:
        pattern = f"%{search}%"
        query = query.join(User).filter(
            or_(
                Task.title.ilike(pattern),
                Task.description.ilike(pattern),
                User.name.ilike(pattern),
                User.email.ilike(pattern),
            )
        )

    if status_filter:
        query = query.filter(Task.status == status_filter)

    if user_id is not None:
        query = query.filter(Task.user_id == user_id)

    tasks = query.order_by(Task.due_date.asc(), Task.id.desc()).all()
    return [_serialize_task(task) for task in tasks]


def update_task_status(db: Session, task_id: int, status: str):
    task = db.query(Task).options(joinedload(Task.user)).filter(Task.id == task_id).first()
    if task is None:
        return None

    task.status = status
    db.commit()
    db.refresh(task)
    return _serialize_task(task)


def delete_task(db: Session, task_id: int) -> bool:
    task = db.query(Task).filter(Task.id == task_id).first()
    if task is None:
        return False

    db.delete(task)
    db.commit()
    return True


def delete_user(db: Session, user_id: int, acting_admin: User) -> bool:
    if user_id == acting_admin.id:
        raise ValueError("You cannot delete the admin account currently in use")

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        return False

    db.delete(user)
    db.commit()
    return True


def _serialize_task(task: Task) -> dict:
    return {
        "id": task.id,
        "title": task.title,
        "description": task.description,
        "priority": task.priority,
        "due_date": task.due_date,
        "status": task.status,
        "user_id": task.user_id,
        "user_name": task.user.name if task.user else "Unknown",
        "user_email": task.user.email if task.user else "Unknown",
    }
