from __future__ import annotations

from pathlib import Path

VAULT = Path.home() / "mqobsidian"
B2_SOURCE_DIR = VAULT / "Prompt-OS" / "B2-Atlas-Prompt-OS"
PROJECT_INDEX = B2_SOURCE_DIR / "PROJECT_INDEX.md"
REGISTRY_JSON = B2_SOURCE_DIR / "registry" / "projects.json"
PROMPTS_DIR = VAULT / "_prompts" / "saved-prompts-md-export"
OBSIDIAN_STACK = VAULT / "mq-stack"
RUNS_DIR = OBSIDIAN_STACK / "runs"
HISTORY_FILE = Path.home() / ".b2tui_history.jsonl"
