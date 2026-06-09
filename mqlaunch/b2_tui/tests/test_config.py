from __future__ import annotations

from pathlib import Path

from mqlaunch.b2_tui import config


def test_vault_is_under_home():
    assert config.VAULT == Path.home() / "mqobsidian"


def test_b2_source_dir_is_under_vault():
    assert config.B2_SOURCE_DIR == config.VAULT / "Prompt-OS" / "B2-Atlas-Prompt-OS"


def test_project_index_is_under_b2_source_dir():
    assert config.PROJECT_INDEX == config.B2_SOURCE_DIR / "PROJECT_INDEX.md"


def test_prompts_dir_is_under_vault():
    assert config.PROMPTS_DIR == config.VAULT / "_prompts" / "saved-prompts-md-export"


def test_runs_dir_is_under_obsidian_stack():
    assert config.RUNS_DIR == config.OBSIDIAN_STACK / "runs"


def test_history_file_is_under_home():
    assert config.HISTORY_FILE == Path.home() / ".b2tui_history.jsonl"


def test_all_paths_are_path_objects():
    path_constants = [
        config.VAULT,
        config.B2_SOURCE_DIR,
        config.PROJECT_INDEX,
        config.REGISTRY_JSON,
        config.PROMPTS_DIR,
        config.OBSIDIAN_STACK,
        config.RUNS_DIR,
        config.HISTORY_FILE,
    ]
    for p in path_constants:
        assert isinstance(p, Path), f"{p!r} is not a Path"
