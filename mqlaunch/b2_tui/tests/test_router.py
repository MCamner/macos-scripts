from __future__ import annotations

from mqlaunch.b2_tui.core.router import ROUTE_PRIMARY, route


def _primary(task: str) -> str:
    best, _, _ = route(task)
    return ROUTE_PRIMARY[best]


def _support_ids(task: str) -> list[str]:
    best, support_routes, _ = route(task)
    return [ROUTE_PRIMARY[r] for r in support_routes]


def _keywords(task: str) -> list[str]:
    _, _, kws = route(task)
    return kws


# --- Primary routing ---

def test_blueprint_routes_to_02_11():
    assert _primary("ta fram blueprint för terminal TUI") == "02.11"


def test_architecture_routes_to_02_11():
    assert _primary("design arkitektur för nytt system") == "02.11"


def test_integration_routes_to_02_11():
    assert _primary("integration mellan komponenter") == "02.11"


def test_implementation_routes_to_02_03():
    assert _primary("skriv kod och implementation") == "02.03"


def test_deploy_routes_to_02_03():
    assert _primary("deploy config och rollback plan") == "02.03"


def test_review_routes_to_02_10():
    assert _primary("granska kontrakt") == "02.10"


def test_audit_routes_to_02_10():
    assert _primary("audit och inspect repo-status") == "02.10"


def test_research_routes_to_04_02():
    assert _primary("undersök ny teknik och evaluation") == "04.02"


def test_compare_routes_to_04_02():
    assert _primary("jämför och analys av market") == "04.02"


def test_content_routes_to_05_03():
    assert _primary("skriv rapport och presentation interaktivt content") == "05.03"


def test_learning_routes_to_06_01():
    assert _primary("förklara och förstå detta koncept") == "06.01"


def test_feynman_routes_to_06_01():
    assert _primary("feynman repetera learning") == "06.01"


def test_decision_routes_to_03_04():
    assert _primary("prioritera roadmap och strategi") == "03.04"


def test_strategy_routes_to_03_04():
    assert _primary("strategi och decide approach") == "03.04"


def test_no_match_defaults_to_architecture():
    primary, _, _ = route("xyzzy nonsense input")
    assert primary == "architecture"


# --- Support projects ---

def test_blueprint_has_support_projects():
    support = _support_ids("ta fram blueprint för terminal TUI")
    assert len(support) >= 1


def test_review_has_architecture_support():
    support = _support_ids("granska arkitektur och kontrakt")
    assert "02.11" in support or "02.03" in support


def test_implementation_has_architecture_support():
    support = _support_ids("skriv kod implementation och design")
    assert len(support) >= 1


# --- Reason / keywords ---

def test_matched_keywords_not_empty_for_clear_task():
    kws = _keywords("ta fram blueprint för integration")
    assert len(kws) > 0


def test_matched_keywords_include_hit():
    kws = _keywords("granska kontrakt")
    assert "granska" in kws or "kontrakt" in kws
