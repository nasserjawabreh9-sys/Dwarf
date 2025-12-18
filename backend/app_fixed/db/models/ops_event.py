from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.app_fixed.db.base import Base

class OpsEvent(Base):
    __tablename__ = "ops_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    type: Mapped[str] = mapped_column(String(100), index=True)
    message: Mapped[str] = mapped_column(String(500))
    created_at: Mapped = mapped_column(DateTime(timezone=True), server_default=func.now())
