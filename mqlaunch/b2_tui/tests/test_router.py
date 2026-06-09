from __future__ import annotations

import argparse
from pathlib import Path
from unittest.mock import patch

from mqlaunch.b2_tui.core.router import ROUTE_PRIMARY, ROUTES, cmd_route
from mqlaunch.b2_tui.models import Prompt

_PROMPTS = [
    Prompt(id="02.11", name="Integration Architecture Blueprint", category="Architecture", path=Path("/fake")),
    Prompt(id="02.03", name="Low-Level Implementation Design", category="Architecture", path=Path("/fake")),
    Prompt(id="02.10", name="Architecture Review", category="Architecture", path=Path("/fake")),
    Prompt(id="05.03", name="Interactive Tool Builder", category="Content", path=Path("/fake")),
    Prompt(id="04.02", name="Tech Research", category="Research", path=Path("/fake")),
    Prompt(id="06.01", name="Learning Explainer", category="Learning", path=Path("/fake")),
    Prompt(id="03.04", name="Decision Framework", category="Decision", path=Path("/fake")),
]


def _route(task: str) -> str:
    task_lower = task.lower()
    scores = {r: sum(1 for kw in kws if kw in task_lower) for r, kws in ROUTES.items()}
    best = max(scores, key=lambda r: scores[r])
    return ROUTE_PRIMARY[best]


def test_blueprint_routes_to_02_11():
    assert _route("ta fram blueprint för terminal TUI") == "02.11"


def test_tui_routes_to_05_03():
    assert _route("skriv rapport och presentation interaktivt content") == "05.03"


def test_review_routes_to_02_10():
    assert _route("granska kontrakt") == "02.10"


def test_code_routes_to_02_03():
    assert _route("skriv kod och implementation") == "02.03"


def test_research_routes_to_04_02():
    assert _route("undersök ny teknik och evaluation") == "04.02"


def test_learning_routes_to_06_01():
    assert _route("förklara och förstå detta koncept") == "06.01"


def test_decision_routes_to_03_04():
    assert _route("prioritera roadmap och strategi") == "03.04"
