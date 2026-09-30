from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = None
    priority: str = "medium"
    due_date: Optional[datetime] = None
    status: str = "pending"


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    due_date: Optional[datetime] = None
    status: Optional[str] = None


class TaskResponse(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    priority: str
    due_date: Optional[datetime] = None
    status: str
    user_id: int

    class Config:
        from_attributes = True
