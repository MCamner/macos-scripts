from __future__ import annotations

import argparse

from mqlaunch.b2_tui.core.project_loader import find_prompt
from mqlaunch.b2_tui.models import Prompt

ROUTES: dict[str, list[str]] = {
    "architecture": [
        "design", "blueprint", "component", "integration", "structure",
        "arkitektur", "system", "hld", "lld", "requirements", "krav",
    ],
    "implementation": [
        "kod", "code", "config", "flow", "test", "rollback",
        "implementation", "bygga", "bygg", "deploy", "operationer", "raci",
    ],
    "review": [
        "granska", "review", "audit", "kontrakt", "repo-status",
        "inspect", "check", "kritik",
    ],
    "research": [
        "undersök", "tech", "evaluation", "research", "ny teknik",
        "market", "analys", "jämför", "compare",
    ],
    "content": [
        "rapport", "presentation", "tui", "tool", "docs", "interactive",
        "report", "write", "skriva", "content",
    ],
    "learning": [
        "förstå", "lär", "concept", "repetera", "learning",
        "explain", "förklara", "feynman",
    ],
    "decision": [
        "prioritera", "välj", "approach", "roadmap", "decision",
        "decide", "strategi", "strategy",
    ],
}

ROUTE_PRIMARY: dict[str, str] = {
    "architecture": "02.11",
    "implementation": "02.03",
    "review": "02.10",
    "research": "04.02",
    "content": "05.03",
    "learning": "06.01",
    "decision": "03.04",
}


def cmd_route(prompts: list[Prompt], args: argparse.Namespace) -> int:
    from mqlaunch.b2_tui.core.prompt_composer import cmd_run

    task = args.task.lower()
    scores: dict[str, int] = {route: 0 for route in ROUTES}
    for route, keywords in ROUTES.items():
        for kw in keywords:
            if kw in task:
                scores[route] += 1

    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    best_route, best_score = ranked[0]

    if best_score == 0:
        print("  No clear route match — defaulting to: architecture")
        best_route = "architecture"

    primary_id = ROUTE_PRIMARY[best_route]
    primary = find_prompt(prompts, primary_id)

    print(f"\n  Route: {best_route}")
    if primary:
        print(f"  Primary prompt: {primary.id} — {primary.name}")
    print()

    print("  All route scores:")
    for route, score in ranked:
        marker = "→" if route == best_route else " "
        pid = ROUTE_PRIMARY[route]
        p = find_prompt(prompts, pid)
        pname = p.name if p else pid
        print(f"  {marker} {route:<14} {score}  ({pid} {pname})")

    if primary and not args.no_run:
        print()
        try:
            run = input("  Run this prompt? [Y/n]: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            return 0
        if run in ("", "y", "yes", "ja"):
            run_args = argparse.Namespace(id=primary.id, context=None)
            return cmd_run(prompts, run_args)

    return 0
