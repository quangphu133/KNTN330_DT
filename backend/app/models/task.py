from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    priority = Column(String(20), nullable=False, default="medium")
    due_date = Column(DateTime, nullable=True)
    status = Column(String(20), nullable=False, default="pending")
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    user = relationship("User", back_populates="tasks")
