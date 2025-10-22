from __future__ import annotations

from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    openai_api_key: str | None = None
    local_model_path: str | None = None
    postgres_dsn: str
    redis_url: str = "redis://localhost:6379/0"
    task_graph_model: str = "gpt-4.1-turbo"
    enable_local_llm: bool = False

    class Config:
        env_prefix = "BREAKDOWN_"
        env_file = ".env"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
