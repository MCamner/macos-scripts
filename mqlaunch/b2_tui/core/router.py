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

# Which routes provide support context for each primary route
ROUTE_SUPPORT: dict[str, list[str]] = {
    "architecture":    ["implementation", "review"],
    "implementation":  ["architecture", "review"],
    "review":          ["architecture", "implementation"],
    "research":        ["decision", "architecture"],
    "content":         ["implementation", "architecture"],
    "learning":        ["decision", "research"],
    "decision":        ["architecture", "research"],
}


def route(task: str) -> tuple[str, list[str], list[str]]:
    """Return (primary_route, support_routes, matched_keywords)."""
    task_lower = task.lower()
    scores: dict[str, int] = {r: 0 for r in ROUTES}
    matched: dict[str, list[str]] = {r: [] for r in ROUTES}

    for r, keywords in ROUTES.items():
        for kw in keywords:
            if kw in task_lower:
                scores[r] += 1
                matched[r].append(kw)

    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    best_route = ranked[0][0] if ranked[0][1] > 0 else "architecture"

    # Support: other routes that also scored > 0, capped at 2
    support = [
        r for r, score in ranked[1:]
        if score > 0 and r in ROUTE_SUPPORT.get(best_route, [])
    ][:2]

    # Fallback support from ROUTE_SUPPORT if nothing else scored
    if not support:
        support = ROUTE_SUPPORT.get(best_route, [])[:2]

    all_matched = matched[best_route] + [kw for r in support for kw in matched[r]]

    return best_route, support, all_matched


def cmd_route(prompts: list[Prompt], args: argparse.Namespace) -> int:
    from mqlaunch.b2_tui.core.prompt_composer import cmd_run

    best_route, support_routes, matched_kws = route(args.task)

    primary_id = ROUTE_PRIMARY[best_route]
    primary = find_prompt(prompts, primary_id)
    support_prompts = [
        p for r in support_routes
        if (p := find_prompt(prompts, ROUTE_PRIMARY[r])) is not None
    ]

    print()
    print("  Primary:")
    if primary:
        print(f"  {primary.id}  {primary.name}")
    else:
        print(f"  {primary_id}")

    if support_prompts:
        print()
        print("  Support:")
        for sp in support_prompts:
            print(f"  {sp.id}  {sp.name}")

    if matched_kws:
        print()
        kw_str = " + ".join(dict.fromkeys(matched_kws))
        print(f"  Reason:")
        print(f"  Task contains {kw_str} signals.")

    if primary and not args.no_run:
        print()
        try:
            run = input("  Compose with this prompt? [Y/n]: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            return 0
        if run in ("", "y", "yes", "ja"):
            run_args = argparse.Namespace(id=primary.id, context=None)
            return cmd_run(prompts, run_args)

    return 0
