from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.app_fixed.db.base import Base

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    created_at: Mapped = mapped_column(DateTime(timezone=True), server_default=func.now())
