from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class AdminSummary(BaseModel):
    total_users: int
    total_tasks: int
    pending_tasks: int
    in_progress_tasks: int
    completed_tasks: int
    admin_users: int


class AdminUserResponse(BaseModel):
    id: int
    name: str
    email: str
    is_admin: bool
    task_count: int


class AdminTaskResponse(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    priority: str
    due_date: Optional[datetime] = None
    status: str
    user_id: int
    user_name: str
    user_email: str


class AdminTaskStatusUpdate(BaseModel):
    status: str
