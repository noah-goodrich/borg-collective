"""FastAPI surface for the hub graph tool (Option C - Story Rail + Focus Lens).

The full 426-item / 72-edge graph is loaded once into memory as the extraction substrate; every
endpoint below only ever returns a small, deterministically laid-out flat sub-DAG (or the curated
story rail). No endpoint ever serializes the whole graph. Reads BORG_MERGE_TREE_DIR at startup
(default ~/.local/state/borg/merge-tree) so the code is fully generic over whatever employer data (or
fixture data) lives there — nothing project-specific is hardcoded.
"""
from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

import graph

APP_DIR = Path(__file__).resolve().parent
STATIC_DIR = APP_DIR / "static"

app = FastAPI(title="borg hub story lens")

_dataset: graph.Dataset | None = None


def get_dataset() -> graph.Dataset:
    global _dataset
    if _dataset is None:
        _dataset = graph.load_dataset()
    return _dataset


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/story")
def api_story() -> dict:
    return get_dataset().enriched_story()


@app.get("/api/lens/{ref}")
def api_lens(ref: str, radius: int = 1, direction: str = "both") -> dict:
    if direction not in ("in", "out", "both"):
        raise HTTPException(400, "direction must be one of in|out|both")
    if radius < 0 or radius > 5:
        raise HTTPException(400, "radius must be between 0 and 5")
    return get_dataset().lens(ref, radius=radius, direction=direction)


@app.get("/api/unblocks")
def api_unblocks() -> list[dict]:
    return get_dataset().unblocks(top=15)


app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
