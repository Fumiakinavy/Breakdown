# Breakdown Backend Prototype

This folder sketches the asynchronous pipeline that pre-computes subtask graphs after a task is created.

## Components

- `config.py`: environment-driven configuration (`BREAKDOWN_*` variables)
- `models.py`: SQLAlchemy ORM definitions with pgvector columns for embeddings
- `pipeline.py`: LangGraph workflow that orchestrates LLM calls, validation, and persistence
- `recommendations.sql`: pgvector query for similar task recommendations
- `requirements.txt`: minimal dependency set for the worker service

## Workflow Summary

1. API enqueues a `task_id` onto Redis after task creation.
2. Worker (`pipeline.py`) fetches historical embeddings, runs the LangGraph pipeline, and writes `SubtaskNode`/`SubtaskEdge` rows.
3. The iOS app fetches `/task/{id}/graph` to render the updated Canvas graph.
4. User edits or feedback events are written back and later influence prompt construction.

The Python code is designed as a reference implementation; integrate it with FastAPI / Celery as needed.
