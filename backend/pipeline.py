from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any, Dict, List, TypedDict

from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.messages import SystemMessage, HumanMessage
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

from config import get_settings

settings = get_settings()


class GraphState(TypedDict):
    task_id: str
    title: str
    detail: str | None
    history_embeddings: List[List[float]]
    user_profile: Dict[str, Any]
    llm_response: Dict[str, Any] | None
    generation: Dict[str, Any] | None


@dataclass
class SubtaskProposal:
    title: str
    parent: str | None
    confidence: float
    rationale: str
    relation: str
    metadata: Dict[str, Any]


prompt = ChatPromptTemplate.from_messages(
    [
        SystemMessage(content="""You are an AI agent that decomposes tasks into a mind-map style graph. \
Each node should be short, actionable, and tailored to the user's history."""),
        HumanMessage(content="""
Task: {title}
Detail: {detail}
User skill profile: {skills}
Historical context embeddings: {history}
Return JSON with nodes[], edges[].
"""),
    ]
)


async def build_llm_chain(model: str) -> ChatOpenAI:
    if settings.enable_local_llm and settings.local_model_path:
        from langchain_community.llms import LlamaCpp

        return LlamaCpp(model_path=settings.local_model_path, n_ctx=4096, temperature=0.3)
    return ChatOpenAI(model=model, temperature=0.3, api_key=settings.openai_api_key)


async def generate_graph(state: GraphState) -> GraphState:
    llm = await build_llm_chain(settings.task_graph_model)
    chain = prompt | llm
    response = await chain.ainvoke(
        {
            "title": state["title"],
            "detail": state["detail"] or "",
            "skills": state["user_profile"].get("skill_signals", {}),
            "history": state["history_embeddings"],
        }
    )
    state["llm_response"] = response.dict()
    return state


async def validate_output(state: GraphState) -> GraphState:
    response = state["llm_response"] or {}
    nodes = response.get("json", {}).get("nodes", [])
    if not nodes:
        state["generation"] = {
            "nodes": [
                {
                    "title": state["title"],
                    "confidence": 1.0,
                    "parent": None,
                    "relation": "root",
                }
            ],
            "edges": [],
        }
        return state
    # simple sanitisation
    normalised_nodes = []
    for node in nodes:
        normalised_nodes.append(
            {
                "title": node.get("title", "Untitled"),
                "parent": node.get("parent"),
                "confidence": max(min(node.get("confidence", 0.6), 1.0), 0.0),
                "relation": node.get("relation", "sequence"),
                "metadata": node.get("metadata", {}),
            }
        )
    state["generation"] = {
        "nodes": normalised_nodes,
        "edges": response.get("json", {}).get("edges", []),
    }
    return state


async def persist_graph(state: GraphState) -> GraphState:
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session

    from models import SubtaskEdge, SubtaskNode, Task

    engine = create_engine(settings.postgres_dsn, future=True)
    proposals = state.get("generation", {})
    with Session(engine) as session:
        task: Task = session.get(Task, state["task_id"])
        if not task:
            return state
        task.graph_version += 1
        session.query(SubtaskNode).filter(SubtaskNode.task_id == task.id).delete()
        session.query(SubtaskEdge).filter(SubtaskEdge.task_id == task.id).delete()
        session.flush()
        nodes: List[SubtaskNode] = []
        for idx, node in enumerate(proposals.get("nodes", [])):
            nodes.append(
                SubtaskNode(
                    task_id=task.id,
                    title=node["title"],
                    parent_node_id=None,
                    ai_proposed_title=node["title"],
                    confidence=node.get("confidence", 0.5),
                    metadata=node.get("metadata", {}),
                    layout_x=0.3 + 0.4 * (idx / max(len(proposals.get("nodes", [])), 1)),
                    layout_y=0.35 + 0.2 * (idx % 2),
                )
            )
        session.add_all(nodes)
        for edge in proposals.get("edges", []):
            session.add(
                SubtaskEdge(
                    task_id=task.id,
                    source_node_id=edge.get("source"),
                    target_node_id=edge.get("target"),
                    relation=edge.get("relation", "sequence"),
                )
            )
        session.commit()
    return state


async def worker(task_id: str, title: str, detail: str | None, history: List[List[float]], profile: Dict[str, Any]) -> None:
    graph = StateGraph(GraphState)
    graph.add_sequence([generate_graph, validate_output, persist_graph])
    graph.set_entry_point(generate_graph)
    graph.add_edge(validate_output, persist_graph)
    graph.add_edge(persist_graph, END)
    app = graph.compile(checkpointer=MemorySaver())

    await app.ainvoke(
        {
            "task_id": task_id,
            "title": title,
            "detail": detail,
            "history_embeddings": history,
            "user_profile": profile,
            "llm_response": None,
            "generation": None,
        }
    )


def run_sync_worker(**kwargs: Any) -> None:
    asyncio.run(worker(**kwargs))
