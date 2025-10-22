from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy_utils import ChoiceType
from pgvector.sqlalchemy import Vector

Base = declarative_base()


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[str] = mapped_column(UUID(as_uuid=True), primary_key=True)
    title: Mapped[str] = mapped_column(String(256), nullable=False)
    detail: Mapped[Optional[str]] = mapped_column(Text)
    priority: Mapped[str] = mapped_column(String(12), nullable=False)
    status: Mapped[str] = mapped_column(String(12), nullable=False, default="draft")
    due_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    user_id: Mapped[str] = mapped_column(UUID(as_uuid=True), nullable=False)
    graph_version: Mapped[int] = mapped_column(Integer, default=1)
    ai_prompt_context: Mapped[Optional[dict]] = mapped_column(JSON)

    nodes: Mapped[list[SubtaskNode]] = relationship(back_populates="task", cascade="all, delete-orphan")
    edges: Mapped[list[SubtaskEdge]] = relationship(back_populates="task", cascade="all, delete-orphan")
    runs: Mapped[list[TaskLLMRun]] = relationship(back_populates="task", cascade="all, delete-orphan")


class SubtaskNode(Base):
    __tablename__ = "subtask_nodes"

    id: Mapped[str] = mapped_column(UUID(as_uuid=True), primary_key=True)
    task_id: Mapped[str] = mapped_column(ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    parent_node_id: Mapped[Optional[str]] = mapped_column(ForeignKey("subtask_nodes.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(256), nullable=False)
    ai_proposed_title: Mapped[Optional[str]] = mapped_column(String(256))
    confidence: Mapped[float] = mapped_column(Float, default=0.5)
    metadata: Mapped[dict] = mapped_column(JSON, default=dict)
    layout_x: Mapped[float] = mapped_column(Float, default=0.5)
    layout_y: Mapped[float] = mapped_column(Float, default=0.5)
    is_user_edited: Mapped[bool] = mapped_column(Boolean, default=False)
    embedding: Mapped[Optional[list[float]]] = mapped_column(Vector(768), nullable=True)

    task: Mapped[Task] = relationship(back_populates="nodes")

    __table_args__ = (
        Index("idx_nodes_task", "task_id"),
        Index("idx_nodes_task_parent", "task_id", "parent_node_id"),
    )


class SubtaskEdge(Base):
    __tablename__ = "subtask_edges"

    id: Mapped[str] = mapped_column(UUID(as_uuid=True), primary_key=True)
    task_id: Mapped[str] = mapped_column(ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    source_node_id: Mapped[str] = mapped_column(ForeignKey("subtask_nodes.id", ondelete="CASCADE"), nullable=False)
    target_node_id: Mapped[str] = mapped_column(ForeignKey("subtask_nodes.id", ondelete="CASCADE"), nullable=False)
    relation: Mapped[str] = mapped_column(String(24), default="sequence")

    task: Mapped[Task] = relationship(back_populates="edges")

    __table_args__ = (
        UniqueConstraint("task_id", "source_node_id", "target_node_id", name="uq_edge_pair"),
    )


class TaskLLMRun(Base):
    __tablename__ = "task_llm_runs"

    id: Mapped[str] = mapped_column(UUID(as_uuid=True), primary_key=True)
    task_id: Mapped[str] = mapped_column(ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    model_name: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(16), default="queued")
    latency_ms: Mapped[Optional[float]] = mapped_column(Float)
    prompt_snapshot: Mapped[dict] = mapped_column(JSON)
    response_snapshot: Mapped[dict] = mapped_column(JSON)

    task: Mapped[Task] = relationship(back_populates="runs")

    __table_args__ = (
        Index("idx_runs_task_status", "task_id", "status"),
    )


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id: Mapped[str] = mapped_column(UUID(as_uuid=True), primary_key=True)
    embedding: Mapped[Optional[list[float]]] = mapped_column(Vector(512))
    scheduling_preference: Mapped[dict] = mapped_column(JSON, default=dict)
    skill_signals: Mapped[dict] = mapped_column(JSON, default=dict)

    __table_args__ = (
        Index("idx_user_profiles_embedding", "embedding", postgresql_using="ivfflat"),
    )
