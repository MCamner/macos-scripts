"""Pure view builders for MQ Dashboard 2.0.

Input is the Collector snapshot: {source_key: envelope}. Output is plain
data (cards, panels, tables, lines) that the curses layer draws. Nothing
here performs I/O except lazy log tails inside detail callbacks.

A Line is a list of (text, kind) segments; kind selects the colour.
"""
from __future__ import annotations

import json
import os
import re
from datetime import datetime, timedelta, timezone

import dashboard_sources as sources

SECTIONS = (
    ("Home", ()),
    ("Repositories", ("Overview", "Provenance")),
    ("MCP Services", ("Overview", "Services", "Logs", "Tool Surface", "Compatibility", "Diagnostics")),
    ("AI Models", ("Overview", "Ollama Models", "Running Models", "OpenAI", "Routing", "Diagnostics")),
    ("Evidence & Learning", ("Overview", "Routing", "Hybrid Retrieval", "Memory", "History", "Export")),
    ("Repair Planner", ("Overview", "Issues", "Analysis", "Fix Plan", "History", "Settings")),
    ("GitHub & Releases", ("Overview", "Pull Requests", "CI Checks", "Releases", "Compatibility", "History")),
    ("Automation", ("Overview", "Jobs", "History", "Failures")),
    ("Help", ("Keys", "Status", "Sources", "Safety")),
)
SECTION_NAMES = tuple(name for name, _ in SECTIONS)
SHORT_NAMES = ("Home", "Repos", "MCP", "AI", "Evidence", "Repair", "GitHub", "Auto", "Help")
PERIODS = (("24h", 1), ("7d", 7), ("30d", 30), ("all", None))

_KIND = {
    "PASS": "pass", "VERIFIED": "pass", "RUNNING": "pass", "OK": "pass", "HEALTHY": "pass",
    "ELIGIBLE": "pass", "AUTHENTICATED": "pass", "CLEAN": "pass", "MATCH": "pass", "PRESENT": "pass",
    "OPEN": "pass", "LOADED": "pass",
    "WARN": "warn", "STALE": "warn", "DIRTY": "warn", "AWAITING_OPERATOR_APPROVAL": "warn",
    "REQUIRED": "warn", "DRIFT": "warn", "DEGRADED": "warn", "INSUFFICIENT_EVIDENCE": "warn",
    "CANDIDATE_WORSE": "warn", "DRAFT": "warn",
    "FAIL": "fail", "FAILED": "fail", "ERROR": "fail", "DOWN": "fail", "BLOCKED": "fail",
    "MISSING": "fail",
    "UNVERIFIED": "info", "UNTESTED": "info", "LOADING": "info", "INFO": "info", "MERGED": "info",
    "CANDIDATE_BETTER": "info", "PROPOSED": "info", "MEASURED": "info",
    "UNAVAILABLE": "muted", "DISABLED": "muted", "CLOSED": "muted", "UNRELEASED": "muted",
    "NOT LOADED": "muted", "NOT RUNNING": "muted",
}
_SEVERITY = {"FAIL": 0, "WARN": 1, "STALE": 2, "UNVERIFIED": 3, "INFO": 4}


def json_text(value) -> str:
    return json.dumps(value, ensure_ascii=False, default=str)


def kind_of(value) -> str:
    return _KIND.get(str(value).strip().upper(), "normal")


def S(text, kind: str = "normal") -> tuple:
    return (str(text), kind)


def St(value) -> tuple:
    """A status token coloured by the shared vocabulary."""
    return (str(value), kind_of(value))


def L(*parts) -> list:
    return [p if isinstance(p, tuple) else S(p) for p in parts]


def kv(label: str, value, width: int = 22) -> list:
    text = "" if value is None else str(value)
    return [S(f"{label:<{width}}", "muted"), (text, kind_of(text) if kind_of(text) != "normal" else "normal")]


def text_of(line: list) -> str:
    return "".join(t for t, _ in line)


class Col:
    def __init__(self, title: str, width: int, priority: int = 0):
        self.title, self.width, self.priority = title, width, priority


class View:
    """One section tab: summary lines, an optional selectable table, details."""

    def __init__(self, lines=None, cols=None, rows=None, detail=None, enter=None):
        self.lines = lines or []
        self.cols = cols or []
        self.rows = rows or []          # list of (cells, payload)
        self.detail = detail            # payload -> list[Line]
        self.enter = enter              # payload -> action dict, or None


def visible_cols(cols: list, width: int) -> list:
    """Drop the least important columns until the table fits."""
    keep = list(range(len(cols)))
    while keep and sum(cols[i].width + 1 for i in keep) > width + 1 and len(keep) > 1:
        drop = max(keep, key=lambda i: (cols[i].priority, i))
        keep.remove(drop)
    return keep


def format_row(cols: list, cells: list, width: int) -> list:
    keep = visible_cols(cols, width)
    line, used = [], 0
    for n, i in enumerate(keep):
        text, kind = cells[i] if isinstance(cells[i], tuple) else (str(cells[i]), "normal")
        w = width - used if n == len(keep) - 1 else cols[i].width
        cell = text[:max(0, w)]
        line.append((cell.ljust(w) if n < len(keep) - 1 else cell, kind))
        if n < len(keep) - 1:
            line.append((" ", "normal"))
        used += w + 1
    return line


def header_row(cols: list, width: int) -> list:
    return [(t, "title") for t, _ in format_row(cols, [(c.title, "title") for c in cols], width)]


# ------------------------------------------------------------ data access

def get(data: dict, key: str):
    env = data.get(key) or {}
    return env.get("data")


def missing(data: dict, key: str) -> list:
    if key in data.get("_pending", ()) and not (data.get(key) or {}).get("ok"):
        return L(S("LOADING", "info"), S(f"  {source_label(key)}", "muted"))
    env = data.get(key)
    reason = (env or {}).get("error") or "not collected"
    return L(S("UNAVAILABLE", "muted"), S(f"  {source_label(key)}: {reason.splitlines()[0][:110] if reason else ''}", "muted"))


def loading(data: dict, key: str) -> bool:
    return key in data.get("_pending", ()) and get(data, key) is None


def source_label(key: str) -> str:
    table = sources.source_table()
    if key in table:
        return table[key][0]
    return {"github": "gh pr list + gh release list", "openai_test": "mqlaunch auth test openai --json",
            "export": "dashboard export", "copy": "pbcopy"}.get(key, key)


def parse_time(value) -> datetime | None:
    if not value:
        return None
    text = str(value).replace("Z", "+00:00")
    # Python 3.9 fromisoformat accepts exactly 3 or 6 fractional digits.
    text = re.sub(r"\.(\d+)", lambda m: "." + m.group(1)[:6].ljust(6, "0"), text)
    try:
        moment = datetime.fromisoformat(text)
    except ValueError:
        return None
    return moment if moment.tzinfo else moment.replace(tzinfo=timezone.utc)


def age(value, now: datetime | None = None) -> str:
    moment = parse_time(value)
    if not moment:
        return "-"
    seconds = int(((now or datetime.now(timezone.utc)) - moment).total_seconds())
    if seconds < 0:
        return "in future"
    for unit, size in (("d", 86400), ("h", 3600), ("m", 60)):
        if seconds >= size:
            return f"{seconds // size}{unit} ago"
    return f"{seconds}s ago"


def short_time(value) -> str:
    moment = parse_time(value)
    return moment.astimezone().strftime("%m-%d %H:%M") if moment else "-"


def gib(value) -> str:
    try:
        return f"{int(value) / 1024 ** 3:.1f} GB"
    except (TypeError, ValueError):
        return "-"


# ------------------------------------------------------- shared derivation

def ci_status(repo: dict) -> str:
    status = str((repo.get("verification") or {}).get("status") or "UNAVAILABLE").upper()
    return {"VERIFIED": "PASS", "FAILED": "FAIL"}.get(status, status)


def worst(statuses) -> str:
    order = ("FAIL", "WARN", "STALE", "UNVERIFIED", "UNAVAILABLE", "PASS")
    present = [s for s in statuses if s in order]
    return min(present, key=order.index) if present else "UNAVAILABLE"


def repos(data: dict) -> list:
    return (get(data, "stack") or {}).get("repos") or []


def scope_rows(data: dict) -> list:
    """CI scopes per repo; a stale repo's green checks are reported STALE."""
    rows = []
    for repo in repos(data):
        verification = repo.get("verification") or {}
        stale = str(verification.get("status", "")).upper() == "STALE"
        for scope in verification.get("scopes") or []:
            status = str(scope.get("status") or "UNAVAILABLE").upper()
            if stale and status == "PASS":
                status = "STALE"
            rows.append({"repo": repo.get("name"), "scope": scope.get("name"), "status": status,
                         "completed": scope.get("completed_at"), "url": scope.get("details_url", "")})
    return rows


def mcp_servers(data: dict) -> dict:
    return (get(data, "mcp") or {}).get("servers") or {}


def ollama(data: dict) -> dict:
    return get(data, "ollama") or {}


def profiles_for(data: dict, model: str) -> str:
    profiles = (get(data, "model_profiles") or {}).get("profiles") or {}
    base = model.split(":")[0]
    hits = [p for p, m in profiles.items() if m == model or (":" not in str(m) and m == base)]
    return ",".join(hits)


def security_warnings(data: dict) -> list:
    warnings = []
    for name, server in mcp_servers(data).items():
        for tool in server.get("tool_specs") or []:
            if tool.get("dangerous"):
                warnings.append(f"{name}: dangerous tool exposed: {tool['name']}")
        # Contract failures are permission-class violations (e.g. a Class C
        # tool inside a profile restricted to Class A/B).
        lines = (server.get("contract") or "").splitlines()
        for n, raw in enumerate(lines):
            if raw.strip().startswith("[FAIL]"):
                why = lines[n + 1].strip() if n + 1 < len(lines) else ""
                warnings.append(f"{name}: contract {raw.strip()[7:]}" + (f" — {why}" if why else ""))
    auth = get(data, "auth") or {}
    if auth.get("consistency") == "different":
        warnings.append("auth: process OPENAI_API_KEY differs from canonical Keychain item")
    return warnings


def openai_state(data: dict) -> tuple[str, str]:
    if loading(data, "openai_test"):
        return "LOADING", "testing"
    test_env = data.get("openai_test")
    if test_env and not test_env.get("ok"):
        return "FAIL", (test_env.get("error") or "test failed")[:40]
    test = get(data, "openai_test")
    if test:
        status = str(test.get("status", "fail")).upper()
        return status, f"HTTP {test.get('http_status') or '-'} · {test.get('round_trip_ms', '-')} ms"
    auth = get(data, "auth")
    if not auth:
        return ("LOADING" if loading(data, "auth") else "UNAVAILABLE"), "auth status"
    if auth.get("effective_source") in (None, "", "none"):
        return "FAIL", "no credential"
    return "UNTESTED", f"{auth.get('effective_source')}"


def health_cards(data: dict) -> list:
    """The seven Stack Health cards: (title, value, status, subtitle)."""
    cards = []
    rs = repos(data)
    if rs:
        statuses = [ci_status(r) for r in rs]
        cards.append(("Repositories", f"{statuses.count('PASS')}/{len(rs)}", worst(statuses), "verified"))
    else:
        cards.append(("Repositories", "-", "LOADING" if loading(data, "stack") else "UNAVAILABLE", "stack status"))
    scopes = scope_rows(data)
    if scopes:
        statuses = [s["status"] for s in scopes]
        cards.append(("GitHub CI", f"{statuses.count('PASS')}/{len(scopes)}", worst(statuses), "checks"))
    else:
        cards.append(("GitHub CI", "-", "LOADING" if loading(data, "stack") else "UNAVAILABLE", "check runs"))
    services = get(data, "services")
    if services:
        up = sum(s["state"] == "RUNNING" for s in services)
        tools = sum(int(s.get("tools") or 0) for s in mcp_servers(data).values())
        cards.append(("MCP Services", f"{up}/{len(services)}", "PASS" if up == len(services) else "FAIL",
                      f"{tools} tools" if tools else "running"))
    else:
        cards.append(("MCP Services", "-", "LOADING" if loading(data, "services") else "UNAVAILABLE", "launchd"))
    lo = get(data, "ollama")
    if lo:
        cards.append(("Local AI", f"{len(lo.get('running') or [])} loaded", "PASS",
                      f"{len(lo.get('models') or [])} installed"))
    else:
        cards.append(("Local AI", "-", "LOADING" if loading(data, "ollama") else "UNAVAILABLE", "ollama api"))
    status, sub = openai_state(data)
    cards.append(("OpenAI API", status if status not in ("PASS", "FAIL") else ("OK" if status == "PASS" else "FAIL"),
                  {"OK": "PASS"}.get(status, status), sub))
    if get(data, "mcp") is not None or get(data, "auth") is not None:
        warnings = security_warnings(data)
        if warnings:
            status = "WARN"
        elif get(data, "mcp") is None or get(data, "auth") is None:
            status = "UNVERIFIED"  # a check that did not run is not a pass
        else:
            status = "PASS"
        cards.append(("Security", f"{len(warnings)} warn", status, "class+auth"))
    else:
        cards.append(("Security", "-", "LOADING" if loading(data, "mcp") else "UNAVAILABLE", "class+auth"))
    compat = get(data, "compatibility")
    if compat:
        pairs = compat.get("relationships") or []
        ok = sum(str(p.get("status", "")).upper() == "PASS" for p in pairs)
        cards.append(("Compatibility", f"{ok}/{len(pairs)}", str(compat.get("status", "UNAVAILABLE")).upper(),
                      "dep pairs"))
    else:
        cards.append(("Compatibility", "-", "LOADING" if loading(data, "compatibility") else "UNAVAILABLE",
                      "stack compatibility"))
    return cards


def overall(data: dict) -> str:
    stack = get(data, "stack")
    if stack:
        return str(stack.get("overall", "UNAVAILABLE"))
    return "LOADING" if loading(data, "stack") else "UNAVAILABLE"


# --------------------------------------------------------------- home panels

def home_panels(data: dict) -> list:
    """(title, section index, lines) in grid order."""
    panels = []
    rs = repos(data)
    lines = [L(S(f"{'Repository':<17}", "title"), S(f"{'Version':<9}", "title"), S(f"{'CI':<11}", "title"), S("Git", "title"))]
    for r in rs:
        lines.append(L(f"{r.get('name', '?'):<17}", S(f"{str(r.get('version') or '-'):<9}", "muted"),
                       S(f"{ci_status(r):<11}", kind_of(ci_status(r))),
                       St("DIRTY" if r.get("dirty") else "CLEAN")))
    panels.append(("REPOSITORIES", 1, lines if rs else [missing(data, "stack")]))

    lines = []
    for s in get(data, "services") or []:
        lines.append(L(f"{s['name']:<17}", S(f":{s['port']:<6}", "muted"), S(s["state"], kind_of(s["state"]))))
    tools = [f"{name} {srv.get('tools')}" for name, srv in mcp_servers(data).items() if srv.get("tools")]
    if tools:
        lines.append(L(S("Tools    ", "muted"), " · ".join(tools)))
    contract = (mcp_servers(data).get("mq-mcp") or {}).get("contract", "")
    head = re.search(r"validation\s+\S+\s+(\w+)", contract)
    if head:
        lines.append(L(S("Contract ", "muted"), St(head.group(1)), S("  see Compatibility", "muted")))
    panels.append(("MCP SERVICES", 2, lines or [missing(data, "services")]))

    lo = get(data, "ollama")
    lines = []
    if lo:
        running = {m.get("name") for m in lo.get("running") or []}
        lines.append(L(S("Ollama ", "muted"), St("RUNNING"), S(f"  v{lo.get('version')}  {len(lo.get('models') or [])} installed", "muted")))
        for m in (lo.get("models") or [])[:5]:
            name = m.get("name", "?")
            lines.append(L(f"  {name[:26]:<27}", St("LOADED") if name in running else S("installed", "muted")))
    else:
        lines.append(missing(data, "ollama"))
    status, sub = openai_state(data)
    lines.append(L(S("OpenAI ", "muted"), St(status), S(f"  {sub}", "muted")))
    panels.append(("AI MODELS", 3, lines))

    routing = get(data, "routing") or {}
    tc = (routing.get("task_classes") or {}).get("docs-review") or {}
    actual = tc.get("actual") or {}
    report = get(data, "feedback_report") or {}
    cands = (get(data, "feedback_candidates") or {}).get("candidates") or []
    lines = []
    if routing:
        lines += [L(S("Readiness   ", "muted"), St(tc.get("recommendation", "UNAVAILABLE"))),
                  L(S("Applied     ", "muted"), f"{actual.get('observations', '-')} obs · {actual.get('window_days', '-')} days"),
                  L(S("Auto route  ", "muted"), St("DISABLED" if not routing.get("automatic_routing_enabled") else "ENABLED"))]
    else:
        lines.append(missing(data, "routing"))
    if report:
        lines.append(L(S("Feedback    ", "muted"), St(report.get("health", "-")),
                       S(f"  {report.get('matched_records', '-')} runs", "muted")))
        reason = (report.get("comparison") or {}).get("reason")
        if reason:
            lines.append(L(S("Comparison  ", "muted"), St(reason)))
    lines.append(L(S("Candidates  ", "muted"), f"{len(cands)} proposed (approval required)"))
    panels.append(("EVIDENCE & LEARNING", 4, lines))

    panels.append(("RECENT RESULTS", 7, recent_results(data)))

    lines = [L(S("gh auth ", "muted"), St((get(data, "gh_auth") or {}).get("status", "LOADING" if loading(data, "gh_auth") else "UNAVAILABLE")))]
    gh = get(data, "github")
    if gh:
        open_prs = [(r["repo"], p) for r in gh["repos"] for p in (r.get("prs") or []) if p.get("state") == "OPEN"]
        lines.append(L(S("Open PRs ", "muted"), str(len(open_prs))))
        for repo, pr in open_prs[:3]:
            lines.append(L(S(f"  {repo[:14]}#{pr['number']} ", "muted"), pr.get("title", "")[:40]))
        latest = sorted(((rel.get("publishedAt", ""), r["repo"], rel.get("tagName")) for r in gh["repos"]
                         for rel in (r.get("releases") or [])), reverse=True)[:3]
        for when, repo, tag in latest:
            lines.append(L(S(f"  {short_time(when)} ", "muted"), f"{repo} {tag}"))
    else:
        lines.append(missing(data, "github"))
    panels.append(("GITHUB & RELEASES", 6, lines))
    return panels


def recent_results(data: dict) -> list:
    lines = []
    snaps = get(data, "snapshots") or {}
    for name in ("stack-status", "routing-divergence"):
        entries = snaps.get(name) or []
        if entries:
            last = entries[-1]
            lines.append(L(S(f"{name:<19}", "muted"), S(f"{last['mtime'][5:16].replace('T', ' ')} ", "muted"), St(last["status"] or "-")))
        else:
            lines.append(L(S(f"{name:<19}", "muted"), St("UNAVAILABLE")))
    ex = get(data, "execution")
    if ex:
        by = ex.get("by_result") or {}
        lines.append(L(S(f"{'execution':<19}", "muted"), S(f"{by.get('PASS', 0)} PASS ", "pass"),
                       S(f"{by.get('FAIL', 0)} FAIL", "fail" if by.get("FAIL") else "muted")))
    hist = get(data, "route_history")
    if hist and hist.get("entries"):
        newest = hist["entries"][0]
        lines.append(L(S(f"{'last route':<19}", "muted"), f"{newest.get('selected_route')} {age(newest.get('recorded_at'))}"))
    report = get(data, "feedback_report")
    if report:
        lines.append(L(S(f"{'last feedback run':<19}", "muted"), age(report.get("newest_recorded_at"))))
    doctor = get(data, "doctor")
    if doctor:
        summary = (doctor.get("source") or {}).get("summary") or {}
        lines.append(L(S(f"{'doctor':<19}", "muted"), St(str(doctor.get("status", "-")).upper()),
                       S(f"  {summary.get('ok', 0)} ok {summary.get('warn', 0)} warn {summary.get('fail', 0)} fail", "muted")))
    return lines or [missing(data, "snapshots")]


# ------------------------------------------------------------ repair planner

_REASON_ANALYSIS = {
    "RTP001_DIRTY_WORKTREE": "The checkout has uncommitted changes, so the running code cannot be tied to a commit.",
    "evidence-older-than-86400s": "CI evidence for this exact HEAD is older than the 24h freshness window; "
                                  "it is not a failure, but it no longer proves the current state.",
    "all-required-checks-passed": "",
}


def detect_issues(data: dict) -> list:
    """DETECT + ANALYZE: cross-source issues, each with a proposed manual fix."""
    issues = []
    uid = os.getuid() if hasattr(os, "getuid") else 0

    def add(severity, component, title, evidence, analysis, command=None, risk="none (read-only)",
            reversible="n/a", verify=None, affected=None):
        issues.append({"severity": severity, "component": component, "title": title, "evidence": evidence,
                       "analysis": analysis, "command": command, "risk": risk, "reversible": reversible,
                       "verify": verify or "mqlaunch dashboard --json", "affected": affected or [component]})

    doctor = get(data, "doctor") or {}
    auth = get(data, "auth") or {}
    for action in doctor.get("actions") or []:
        check = action.get("check", "?")
        sev = "FAIL" if action.get("observed_status") == "fail" else "WARN"
        analysis = f"Doctor check '{check}' reported '{action.get('observed_detail', '')}'."
        if check == "OPENAI_API_KEY" and auth.get("effective_source") == "keychain":
            sev = "INFO"
            analysis = ("Doctor reads the process environment only. mqlaunch auth reports the canonical Keychain "
                        "item as present and effective, so tools that read the Keychain are unaffected.")
        add(sev, f"doctor:{check}", f"{check}: {action.get('observed_detail', action.get('observed_status'))}",
            "mqlaunch doctor --fix-plan --json", analysis, action.get("command"),
            verify=action.get("verify"), affected=["macos-scripts"])

    for r in repos(data):
        status = ci_status(r)
        reason = (r.get("verification") or {}).get("reason", "")
        if status != "PASS":
            add(status if status in _SEVERITY else "UNVERIFIED", r.get("name", "?"),
                f"CI evidence {status.lower()}: {reason}", "mq-agent stack status --json",
                _REASON_ANALYSIS.get(reason) or f"Verification reported {status} ({reason}).",
                f"gh run list --repo {(get(data, 'github') or {}).get('owner', '<owner>')}/{r.get('github_repo', r.get('name'))} --limit 5",
                verify="mq-agent stack status --json")
        if r.get("dirty"):
            add("WARN", r.get("name", "?"), "uncommitted changes in checkout", "mq-agent stack status --json",
                "Local changes are not covered by any CI evidence.", f"git -C ~/{r.get('github_repo', r.get('name'))} status -sb")

    for comp in (get(data, "provenance") or {}).get("components") or []:
        if str(comp.get("status", "")).upper() != "PASS":
            reasons = comp.get("reasons") or []
            path = (comp.get("checkout") or {}).get("path", "")
            add(str(comp.get("status", "WARN")).upper() if str(comp.get("status", "")).upper() in _SEVERITY else "WARN",
                comp.get("name", "?"), "provenance: " + (", ".join(reasons) or "layers disagree"),
                "mq-agent stack provenance --json",
                " ".join(_REASON_ANALYSIS.get(x, x) for x in reasons) or "Checkout, install and running layers disagree.",
                f"git -C {path} status -sb" if path else None, verify="mq-agent stack provenance --json")

    for s in get(data, "services") or []:
        if s["state"] != "RUNNING":
            add("FAIL", s["name"], f"service {s['state'].lower()} on :{s['port']}", "launchctl print + lsof",
                f"launchd state '{s['launchd_state']}', listening={s['listening']}, last exit {s['last_exit'] or '-'}.",
                f"launchctl kickstart -k gui/{uid}/{s['label']}", risk="medium: restarts the service",
                reversible="yes (restart again)", verify=f"lsof -nP -iTCP:{s['port']} -sTCP:LISTEN")

    for job in get(data, "jobs") or []:
        code = str(job.get("last_exit", ""))
        # 143 is SIGTERM from a launchd restart; "(never exited)" means still running.
        if code and code not in ("0", "143", "(never exited)"):
            add("WARN", job["label"], f"scheduled job last exit {code}", "launchctl print",
                "The last scheduled run did not exit cleanly; see Automation > Failures for the error log.",
                f"tail -n 40 {job.get('stderr') or '~/mq-evidence/launchd-error.log'}")

    compat = get(data, "compatibility") or {}
    for finding in compat.get("findings") or []:
        text = finding.get("detail") or finding.get("message") or json_text(finding) if isinstance(finding, dict) else str(finding)
        status = str(finding.get("status", "WARN")).upper() if isinstance(finding, dict) else "WARN"
        add(status if status in _SEVERITY else "WARN", "stack compatibility", text[:70],
            "mq-agent stack compatibility --json", text,
            compat.get("next_action") or None, verify="mq-agent stack compatibility --json")

    routing = get(data, "routing") or {}
    if routing.get("invalid_records"):
        add("WARN", "mq-agent routing", f"{routing['invalid_records']} invalid route records",
            "mq-agent route readiness --json", "Invalid records are excluded from readiness gates.",
            "mq-agent route history --json")
    report = get(data, "feedback_report") or {}
    if report and (report.get("health") != "HEALTHY" or report.get("degraded_reasons")):
        add("WARN", "mq-agent feedback", f"feedback {report.get('health')}", "mq-agent feedback report --json",
            "; ".join(report.get("degraded_reasons") or []) or "Feedback storage is not healthy.",
            "mq-agent feedback status --json")
    contract = (mcp_servers(data).get("mq-mcp") or {}).get("contract", "")
    match = re.search(r"Checks:\s*(\d+) passed,\s*(\d+) failed", contract)
    if match and int(match.group(2)):
        add("WARN", "mq-mcp", f"orchestration contract: {match.group(2)} checks failed", "mq-agent mcp status --json",
            "mq-mcp's validate_orchestration_contract reports failing checks; see MCP Services > Compatibility.",
            "mq-agent mcp status --json")
    if (data.get("inbox") or {}).get("error"):
        add("STALE", "mqobsidian", "promotion inbox: " + data["inbox"]["error"][:60], "mq-agent obsidian inbox list --json",
            "mqobsidian's canonical inbox export is older than its source; candidates may be missing.",
            None, verify="mq-agent obsidian inbox list --json")
    if data.get("ollama") and not data["ollama"].get("ok"):
        add("WARN", "ollama", "local Ollama API unreachable", "GET 127.0.0.1:11434/api/version",
            "Local models cannot be listed or served while the Ollama server is down.",
            "open -a Ollama", risk="low: starts the Ollama app", reversible="yes (quit Ollama)")
    # Every expected source that is not measured is an issue: absence of data
    # must never read as "no problems".
    handled = {k for k in ("inbox", "ollama") if data.get(k)}  # failures already reported above
    for key in list(sources.source_table()) + ["github"]:
        env = data.get(key)
        if key in handled or (env or {}).get("ok") or key in data.get("_pending", ()):
            continue
        add("UNVERIFIED", f"source:{key}", f"source unavailable: {source_label(key)}", source_label(key),
            ((env or {}).get("error") or "not collected")[:200], None)
    issues.sort(key=lambda i: (_SEVERITY.get(i["severity"], 9), i["component"]))
    return issues


# ------------------------------------------------------------ section views

def build_view(section: int, tab: int, data: dict, ui: dict | None = None) -> View:
    ui = ui or {}
    name = SECTION_NAMES[section]
    tabs = SECTIONS[section][1]
    tab_name = tabs[tab % len(tabs)] if tabs else ""
    builder = _BUILDERS.get((name, tab_name))
    if builder is None:
        return View([L(S("UNAVAILABLE", "muted"), S("  no view", "muted"))])
    return builder(data, ui)


def _repos_overview(data, ui):
    rs = repos(data)
    if not rs:
        return View([missing(data, "stack")])
    stack = get(data, "stack") or {}
    review = [r["name"] for r in rs if ci_status(r) != "PASS" or r.get("dirty")]
    lines = [L(S("Overall ", "muted"), St(stack.get("overall", "-")),
               S(f"   checked {age(stack.get('checked_at'))} · max age {int(stack.get('max_age_seconds', 0)) // 3600}h", "muted")),
             L(S("Needs review ", "muted"), S(", ".join(review) or "none", "warn" if review else "pass")),
             L(S("CI PASS proves the commit on GitHub, not this machine's install (see Provenance).", "muted"))]
    cols = [Col("Repository", 17), Col("Version", 8, 2), Col("Branch", 10, 3), Col("Commit", 8, 4),
            Col("CI", 11), Col("Git", 6, 1), Col("Activity", 14, 5)]
    rows = [([S(r.get("name", "?")), S(r.get("version") or "-", "muted"), S(r.get("branch") or "-", "muted"),
              S((r.get("commit") or "-")[:8], "muted"), St(ci_status(r)), St("DIRTY" if r.get("dirty") else "CLEAN"),
              S(r.get("last_activity") or "-", "muted")], r) for r in rs]

    def detail(r):
        v = r.get("verification") or {}
        out = [kv("Role", r.get("role")), kv("GitHub repo", r.get("github_repo")),
               kv("Branch / commit", f"{r.get('branch')} {(r.get('commit') or '')[:12]}"),
               kv("Worktree", "DIRTY" if r.get("dirty") else "CLEAN"),
               kv("Verification", ci_status(r)), kv("Reason", v.get("reason")),
               kv("Verified", f"{short_time(v.get('verified_at'))} ({age(v.get('verified_at'))})"),
               kv("Scopes", f"{v.get('verified_count', '-')}/{v.get('required_count', '-')}"), []]
        for scope in v.get("scopes") or []:
            out.append(L(S("  "), St(f"{scope.get('status', '?'):<6}"), f" {scope.get('name')}",
                         S(f"  {age(scope.get('completed_at'))}", "muted")))
        return out
    return View(lines, cols, rows, detail)


def _repos_provenance(data, ui):
    prov = get(data, "provenance")
    if not prov:
        return View([missing(data, "provenance")])
    lines = [L(S("Checkout vs installed vs running vs release, local only. ", "muted"),
               S(f"remote verified: {prov.get('remote_verified')}", "muted"))]
    cols = [Col("Component", 16), Col("Status", 7), Col("Installed", 10, 2), Col("Head", 9, 3), Col("Reasons", 30, 1)]
    rows = []
    for c in prov.get("components") or []:
        rows.append(([S(c.get("name")), St(c.get("status", "-")), S((c.get("installed") or {}).get("version") or "-", "muted"),
                      S(((c.get("checkout") or {}).get("head") or "-")[:8], "muted"),
                      S(", ".join(c.get("reasons") or []) or "-", "warn" if c.get("reasons") else "muted")], c))

    def detail(c):
        out = [kv("Checkout", (c.get("checkout") or {}).get("path")),
               kv("Worktree clean", (c.get("checkout") or {}).get("worktree_clean")),
               kv("Running probe", (c.get("running_probe") or {}).get("endpoint") or "not attempted"),
               kv("Reachable", (c.get("running_probe") or {}).get("reachable")), [], L(S("Comparison", "title"))]
        for key, value in (c.get("comparison") or {}).items():
            out.append(kv("  " + key.replace("_", " "), "-" if value is None else str(value).upper(), 30))
        integration = c.get("integration") or {}
        out.append(kv("Ahead / behind", f"{integration.get('ahead')} / {integration.get('behind')}"))
        release = c.get("release") or {}
        out.append(kv("Release tag", f"{release.get('latest_tag')} (declared {release.get('declared_version')})"))
        return out
    return View(lines, cols, rows, detail)


def _mcp_overview(data, ui):
    lines = []
    for s in get(data, "services") or []:
        lines.append(L(f"{s['name']:<18}", S(f"localhost:{s['port']:<6} ", "muted"), St(s["state"]),
                       S(f"  pid {s['pid'] or '-'}", "muted")))
    if not get(data, "services"):
        lines.append(missing(data, "services"))
    lines.append([])
    servers = mcp_servers(data)
    for name, srv in servers.items():
        write = sum(t["write_capable"] for t in srv.get("tool_specs") or [])
        lines.append(L(f"{name:<18}", St("PASS" if srv.get("available") else "DOWN"),
                       S(f"  {srv.get('tools', '-')} tools · {write} write-capable · {srv.get('endpoint')}", "muted")))
    if not servers:
        lines.append(missing(data, "mcp"))
    lines += [[], L(S("Read-only view. Restarts are proposed in Repair Planner and run by you, never here.", "muted"))]
    return View(lines)


def _service_rows(data):
    cols = [Col("Service", 18), Col("Port", 6), Col("Status", 12), Col("PID", 7, 1), Col("Runs", 5, 2)]
    rows = [([S(s["name"]), S(str(s["port"]), "muted"), St(s["state"]), S(s["pid"] or "-", "muted"),
              S(s["runs"] or "-", "muted")], s) for s in get(data, "services") or []]
    return cols, rows


def _mcp_services(data, ui):
    if not get(data, "services"):
        return View([missing(data, "services")])
    cols, rows = _service_rows(data)
    uid = os.getuid() if hasattr(os, "getuid") else 0

    def detail(s):
        srv = mcp_servers(data).get(s["name"]) or {}
        out = [kv("Label", s["label"]), kv("launchd state", s["launchd_state"]), kv("PID", s["pid"] or "-"),
               kv("Last restart", s["started"] or "-"), kv("Runs / last exit", f"{s['runs']} / {s['last_exit']}"),
               kv("Runtime path", s["program"] or "-"), kv("LaunchAgent", s["launch_agent"] or "-"),
               kv("Tool compatibility", f"{srv.get('tools', '-')} tools via {srv.get('endpoint', '-')}")]
        if s["state"] != "RUNNING":
            out += [[], L(S("Suggested (manual, needs your approval):", "warn")),
                    L(f"  launchctl kickstart -k gui/{uid}/{s['label']}")]
        return out
    return View([L(S("Tab: focus details · Enter on a stopped service copies the suggested restart.", "muted"))],
                cols, rows, detail,
                enter=lambda s: ({"kind": "copy", "text": f"launchctl kickstart -k gui/{uid}/{s['label']}"}
                                 if s["state"] != "RUNNING" else None))


def _mcp_logs(data, ui):
    if not get(data, "services"):
        return View([missing(data, "services")])
    cols, rows = _service_rows(data)

    def detail(s):
        out = [L(S(f"stderr  {s['stderr']}", "title"))]
        out += [L(S(x, "muted")) for x in sources.read_tail(s["stderr"], 12)] or [L(S("(empty)", "muted"))]
        out += [[], L(S(f"stdout  {s['stdout']}", "title"))]
        out += [L(S(x, "muted")) for x in sources.read_tail(s["stdout"], 12)] or [L(S("(empty)", "muted"))]
        return out
    return View([L(S("Last log lines, credential patterns redacted.", "muted"))], cols, rows, detail)


def _mcp_tools(data, ui):
    servers = mcp_servers(data)
    if not servers:
        return View([missing(data, "mcp")])
    lines = []
    rows = []
    for name, srv in servers.items():
        specs = srv.get("tool_specs") or []
        tally = {}
        for t in specs:
            tally[t["safety_class"]] = tally.get(t["safety_class"], 0) + 1
        lines.append(L(f"{name:<18}", S(" · ".join(f"{k} {v}" for k, v in sorted(tally.items())), "muted")))
        for t in sorted(specs, key=lambda t: (not t["dangerous"], not t["write_capable"], t["name"])):
            rows.append(([S(name, "muted"), S(t["name"]), S(t["safety_class"], "warn" if t["write_capable"] else "muted"),
                          St("FAIL" if t["dangerous"] else "-")], t))
    warnings = security_warnings(data)
    lines.append(L(S("Security warnings ", "muted"), St("PASS" if not warnings else "WARN"), S(f"  {len(warnings)}", "muted")))
    lines += [L(S(f"  · {w}", "warn")) for w in warnings[:3]]
    cols = [Col("Server", 17, 2), Col("Tool", 30), Col("Class", 14), Col("Dangerous", 9, 1)]
    return View(lines, cols, rows, lambda t: [kv(k, v) for k, v in t.items()])


def _mcp_compat(data, ui):
    lines = []
    contract = (mcp_servers(data).get("mq-mcp") or {}).get("contract", "")
    if contract:
        for raw in contract.splitlines():
            raw = raw.strip().lstrip("#").strip()
            if not raw:
                continue
            tag = re.match(r"\[(PASS|FAIL|WARN)\]", raw)
            lines.append(L(S(raw, kind_of(tag.group(1)) if tag else ("title" if "validation" in raw else "normal"))))
    else:
        lines.append(missing(data, "mcp"))
    lines.append([])
    for c in (get(data, "provenance") or {}).get("components") or []:
        if c.get("name") == "mq-mcp":
            lines.append(L(S("Provenance mq-mcp ", "title"), St(c.get("status", "-"))))
            for key, value in (c.get("comparison") or {}).items():
                lines.append(kv("  " + key.replace("_", " "), "-" if value is None else str(value).upper(), 30))
    return View(lines)


def _mcp_diag(data, ui):
    lines = []
    for s in get(data, "services") or []:
        lines += [L(S(s["name"], "title")),
                  L(S("  launchd loaded   ", "muted"), St("PASS" if s["launchd_state"] != "not loaded" else "FAIL")),
                  L(S("  process running  ", "muted"), St("PASS" if s["launchd_state"] == "running" else "FAIL")),
                  L(S("  port listening   ", "muted"), St("PASS" if s["listening"] else "FAIL")),
                  L(S("  endpoint answers ", "muted"), St("PASS" if (mcp_servers(data).get(s["name"]) or {}).get("available") else "UNAVAILABLE")),
                  L(S(f"  last exit        {s['last_exit'] or '-'}", "muted"))]
    for key in ("services", "mcp"):
        env = data.get(key) or {}
        lines.append(L(S(f"source {key:<10}", "muted"), St("PASS" if env.get("ok") else "UNAVAILABLE"),
                       S(f"  {env.get('elapsed_ms', '-')} ms {env.get('error', '')[:60]}", "muted")))
    return View(lines)


def _ai_overview(data, ui):
    lo = get(data, "ollama")
    lines = [L(S("LOCAL AI", "title"))]
    if lo:
        running = lo.get("running") or []
        lines += [kv("Ollama API", f"RUNNING v{lo.get('version')}"),
                  kv("Installed models", len(lo.get("models") or [])),
                  kv("Loaded models", ", ".join(m.get("name", "?") for m in running) or "none (installed ≠ running)")]
    else:
        lines.append(missing(data, "ollama"))
    mem = get(data, "memory") or {}
    if mem:
        lines.append(kv("Memory", f"{gib(mem.get('total_bytes'))} total · ~{gib(mem.get('approx_available_bytes'))} free+inactive"))
    prof = get(data, "model_profiles") or {}
    for p, m in (prof.get("profiles") or {}).items():
        lines.append(kv(f"  profile {p}", f"{m}{'  (active)' if p == prof.get('profile') else ''}"))
    status, sub = openai_state(data)
    lines += [[], L(S("OPENAI", "title")), kv("API", status), kv("Detail", sub),
              L(S("Key material is never read or shown by the dashboard.", "muted"))]
    return View(lines)


def _ai_models(data, ui):
    lo = get(data, "ollama")
    if not lo:
        return View([missing(data, "ollama")])
    running = {m.get("name") for m in lo.get("running") or []}
    cols = [Col("Model", 30), Col("Params", 7, 1), Col("Quant", 7, 3), Col("Size", 8, 2), Col("Context", 8, 1),
            Col("State", 9), Col("Profiles", 14, 4)]
    rows = []
    for m in lo.get("models") or []:
        d = m.get("details") or {}
        name = m.get("name", "?")
        rows.append(([S(name), S(d.get("parameter_size") or "-", "muted"), S(d.get("quantization_level") or "-", "muted"),
                      S(gib(m.get("size")), "muted"), S(str(d.get("context_length") or "-"), "muted"),
                      St("LOADED") if name in running else S("installed", "muted"),
                      S(profiles_for(data, name) or "-", "info")], m))

    def detail(m):
        d = m.get("details") or {}
        return [kv("Family", ", ".join(d.get("families") or [d.get("family") or "-"])), kv("Format", d.get("format")),
                kv("Context window", d.get("context_length") or "-"), kv("Modified", short_time(m.get("modified_at"))),
                kv("Digest", (m.get("digest") or "")[:16]), kv("Used by profiles", profiles_for(data, m.get("name", "")) or "-"),
                [], L(S("Installed is not running: see Running Models.", "muted"))]
    return View([L(S(f"{len(rows)} installed · source /api/tags (does not start Ollama)", "muted"))], cols, rows, detail)


def _ai_running(data, ui):
    lo = get(data, "ollama")
    if not lo:
        return View([missing(data, "ollama")])
    mem = get(data, "memory") or {}
    lines = [kv("Memory total", gib(mem.get("total_bytes"))),
             kv("Approx. available", gib(mem.get("approx_available_bytes")) + " (vm_stat free+inactive)")]
    cols = [Col("Model", 30), Col("Size", 8), Col("VRAM", 8, 1), Col("Expires", 14, 2)]
    rows = [([S(m.get("name", "?")), S(gib(m.get("size")), "muted"), S(gib(m.get("size_vram")), "muted"),
              S(short_time(m.get("expires_at")), "muted")], m) for m in lo.get("running") or []]
    if not rows:
        lines.append(L(S("No models loaded right now. Installed models are not running models.", "muted")))
    return View(lines, cols, rows, lambda m: [kv(k, v) for k, v in m.items() if not isinstance(v, (dict, list))])


def _ai_openai(data, ui):
    auth = get(data, "auth")
    lines = [L(S("AUTH STATUS (local, no network)", "title"))]
    if auth:
        lines += [kv("Status", str(auth.get("status", "-")).upper()),
                  kv("Keychain item", str((auth.get("keychain") or {}).get("status", "-")).upper()),
                  kv("Process env", str((auth.get("process") or {}).get("status", "-")).upper()),
                  kv("Consistency", auth.get("consistency")), kv("Effective source", auth.get("effective_source"))]
    else:
        lines.append(missing(data, "auth"))
    lines += [[], L(S("EXPLICIT CONNECTION TEST", "title"))]
    test = data.get("openai_test")
    if loading(data, "openai_test"):
        lines.append(L(St("LOADING"), S("  request in flight…", "muted")))
    elif test and test.get("ok"):
        t = test["data"]
        lines += [kv("Result", str(t.get("status", "-")).upper()), kv("HTTP", t.get("http_status")),
                  kv("Reason", t.get("reason")), kv("Round trip", f"{t.get('round_trip_ms')} ms (incl. Keychain read)"),
                  kv("Tested at", test.get("at"))]
    elif test:
        lines.append(L(St("FAIL"), S("  " + test.get("error", ""), "muted")))
    else:
        lines.append(L(St("UNTESTED"), S("  Enter runs one API request (asks first).", "muted")))
    lines += [[], kv("Integrations", "UNAVAILABLE (no integration registry source)"),
              L(S("API keys are never displayed.", "muted"))]
    return View(lines, enter=lambda _: {"kind": "openai_test"}, rows=[([S("Run explicit OpenAI API test")], None)],
                cols=[Col("Action", 40)])


def _ai_routing(data, ui):
    routing = get(data, "routing")
    if not routing:
        return View([missing(data, "routing")])
    lines = [kv("Automatic routing", "ENABLED" if routing.get("automatic_routing_enabled") else "DISABLED"),
             kv("Operator approval", "REQUIRED" if routing.get("operator_approval_required") else "-")]
    prof = get(data, "model_profiles") or {}
    lines.append(kv("Active profile", f"{prof.get('profile', '-')} → {prof.get('model', '-')}"))
    for name, tc in (routing.get("task_classes") or {}).items():
        lines += [[], L(S(name, "title"), S("  "), St(tc.get("recommendation", "-")))]
        for route, count in sorted((tc.get("routes") or {}).items()):
            lines.append(kv(f"  {route}", count))
    hist = (get(data, "route_history") or {}).get("entries") or []
    if hist:
        lines += [[], L(S("Latest decisions", "title"))]
        for e in hist[:6]:
            lines.append(L(S(f"  {short_time(e.get('recorded_at'))} ", "muted"), f"{e.get('task_class')} → {e.get('selected_route')}",
                           S(f"  {e.get('local_model') or ''}", "muted")))
    return View(lines)


def _ai_diag(data, ui):
    lines = []
    doctor = get(data, "doctor")
    if doctor:
        for check in (doctor.get("source") or {}).get("checks") or []:
            if "ollama" in check["name"] or "OPENAI" in check["name"]:
                lines.append(L(f"{check['name']:<18}", St(check["status"].upper()), S(f"  {check.get('detail', '')}", "muted")))
    else:
        lines.append(missing(data, "doctor"))
    for key in ("ollama", "model_profiles", "auth", "memory"):
        env = data.get(key) or {}
        lines.append(L(S(f"source {key:<15}", "muted"), St("PASS" if env.get("ok") else "UNAVAILABLE"),
                       S(f"  {env.get('elapsed_ms', '-')} ms {env.get('error', '')[:60]}", "muted")))
    return View(lines)


def _ev_overview(data, ui):
    routing = get(data, "routing") or {}
    tc = (routing.get("task_classes") or {}).get("docs-review") or {}
    actual = tc.get("actual") or {}
    report = get(data, "feedback_report") or {}
    cands = (get(data, "feedback_candidates") or {}).get("candidates") or []
    review = memory_counts(get(data, "memory_review") or "")
    lines = [L(S("ROUTING READINESS", "title"))]
    lines += ([kv("Recommendation", tc.get("recommendation")), kv("Observations", f"{actual.get('observations')} / 20 applied"),
               kv("Ignored (not applied)", routing.get("observations_ignored_not_applied")),
               kv("Approval", "REQUIRED" if routing.get("operator_approval_required") else "-")]
              if routing else [missing(data, "routing")])
    lines += [[], L(S("FEEDBACK EXPERIMENTS", "title"))]
    lines += ([kv("Health", report.get("health")), kv("Runs", report.get("matched_records")),
               kv("Comparison", (report.get("comparison") or {}).get("reason")),
               kv("Latest measurement", f"{short_time(report.get('newest_recorded_at'))} ({age(report.get('newest_recorded_at'))})")]
              if report else [missing(data, "feedback_report")])
    lines += [[], L(S("MEMORY", "title"))]
    lines += ([kv("Observations", review.get("observations")), kv("Candidates", review.get("candidate")),
               kv("Promoted", review.get("promoted")), kv("Held for review", review.get("held"))]
              if review else [missing(data, "memory_review")])
    lines.append(kv("Improvement candidates", f"{len(cands)} ({', '.join(sorted({c.get('state', '?') for c in cands})) or '-'})"))
    return View(lines)


def memory_counts(text: str) -> dict:
    counts = {}
    for key, value in re.findall(r"^\s*(observations|memories|observed|candidate|promoted|deprecated|held|quarantined):\s+(\d+)",
                                 text, re.MULTILINE):
        counts.setdefault(key, int(value))
    return counts


def _ev_routing(data, ui):
    routing = get(data, "routing")
    if not routing:
        return View([missing(data, "routing")])
    lines = []
    for name, tc in (routing.get("task_classes") or {}).items():
        actual = tc.get("actual") or {}
        th = routing.get("thresholds") or {}
        lines += [L(S(f"{name.upper()} ", "title"), St(tc.get("recommendation", "-")), S(f"  eligible {tc.get('eligible')}", "muted")),
                  kv("  Observations", f"{actual.get('observations')} / {th.get('minimum_observations')}"),
                  kv("  Candidate routes", f"{actual.get('candidate_routes')} / {th.get('minimum_candidate_routes')}"),
                  kv("  Window (days)", f"{actual.get('window_days')} / {th.get('minimum_window_days')}"),
                  kv("  Min samples/route", f"{actual.get('minimum_samples_per_route')} / {th.get('minimum_samples_per_route')}"),
                  L(S("  Routes", "muted"))]
        for route, count in sorted((tc.get("routes") or {}).items()):
            lines.append(kv(f"    {route}", count))
        lines.append(L(S("  Gates", "muted")))
        for gate, ok in (tc.get("gates") or {}).items():
            lines.append(L(S(f"    {gate:<28}", "muted"), St("PASS" if ok else "BLOCKED")))
    div = get(data, "divergence")
    if div:
        era = div.get("era") or {}
        lines += [[], L(S("DIVERGENCE (current era) ", "title"), St(div.get("status", "-"))),
                  kv("  Era", f"{era.get('name')} since {short_time(era.get('starts_at'))}")]
        for reason in div.get("insufficient_reasons") or []:
            lines.append(L(S(f"  · {reason}", "muted")))
    lines += [[], L(S("Readiness does not authorize automatic routing.", "muted"))]
    return View(lines)


def _ev_hybrid(data, ui):
    report = get(data, "feedback_report")
    if not report:
        return View([missing(data, "feedback_report")])
    comp = report.get("comparison") or {}
    lines = [kv("Active strategies", ", ".join(report.get("active_strategies") or [])),
             kv("Shadow strategies", ", ".join(report.get("shadow_strategies") or [])),
             L(S("Comparison           ", "muted"), St(comp.get("reason", comp.get("status", "-"))),
               S(f"  {comp.get('records', '-')} records", "muted")), [],
             L(S("Values as reported by mq.feedback-report.v1 (aggregate deltas).", "muted"))]
    cols = [Col("Metric", 28), Col("Status", 12), Col("Value", 12)]
    metrics = report.get("metrics") or {}
    rows = [([S(k), St("MEASURED" if v.get("status") == "measured" else "UNAVAILABLE"),
              S("-" if v.get("value") is None else str(v.get("value")))], (k, v)) for k, v in metrics.items()]
    for name in ("precision", "recall", "channel_coverage", "contradiction_rate"):
        if name not in metrics:
            rows.append(([S(name), St("UNAVAILABLE"), S("not in source", "muted")], (name, {})))
    cands = (get(data, "feedback_candidates") or {}).get("candidates") or []

    def detail(item):
        out = [kv("Metric", item[0])] + [kv(k, v) for k, v in item[1].items()]
        out += [[], L(S("Candidates (proposal only)", "title"))]
        for c in cands:
            out += [L(St(str(c.get("state", "-")).upper()), f"  {c.get('current_strategy')} → {c.get('proposed_strategy')}")]
            out += [L(S(f"    + {g}", "pass")) for g in c.get("gains") or []]
            out += [L(S(f"    - {r}", "fail")) for r in c.get("regressions") or []]
        return out
    return View(lines, cols, rows, detail)


def _ev_memory(data, ui):
    text = get(data, "memory_review")
    lines = [L(S("mq-agent memory review-status", "title"))]
    lines += [L(S(x)) for x in text.splitlines()] if text else [missing(data, "memory_review")]
    lines += [[], L(S("Promotion inbox ", "title"),
                    St("STALE") if (data.get("inbox") or {}).get("error") else St("PASS" if get(data, "inbox") else "UNAVAILABLE"))]
    inbox = get(data, "inbox")
    if inbox:
        for c in (inbox.get("candidates") or [])[:10]:
            lines.append(L(f"  {c.get('id', c.get('candidate_id', '?'))}", S(f"  {c.get('state', '')} {c.get('confidence', '')}", "muted")))
    elif data.get("inbox"):
        lines.append(L(S("  " + data["inbox"].get("error", ""), "muted")))
    lines += [[], L(S("Promotion happens in mq-agent with approval; the dashboard only reads.", "muted"))]
    return View(lines)


def _ev_history(data, ui):
    hist = get(data, "route_history")
    if not hist:
        return View([missing(data, "route_history")])
    label, days = PERIODS[ui.get("period", 3) % len(PERIODS)]
    now = datetime.now(timezone.utc)
    entries = [e for e in hist.get("entries") or []
               if days is None or (parse_time(e.get("recorded_at")) or now) >= now - timedelta(days=days)]
    tally = {}
    for e in entries:
        tally[e.get("selected_route")] = tally.get(e.get("selected_route"), 0) + 1
    lines = [L(S("Period ", "muted"), S(label, "accent"), S("  (P cycles 24h/7d/30d/all)  ", "muted"),
               S(" · ".join(f"{k} {v}" for k, v in sorted(tally.items(), key=lambda kv_: str(kv_[0]))) or "no entries", "muted"))]
    cols = [Col("Recorded", 12), Col("Task", 12, 2), Col("Route", 20), Col("Model", 18, 3), Col("Schema", 7, 1), Col("Applied", 8, 4)]
    rows = [([S(short_time(e.get("recorded_at")), "muted"), S(e.get("task_class")), S(e.get("selected_route")),
              S(e.get("local_model") or "-", "muted"), St("PASS" if e.get("schema_valid") else "FAIL"),
              S(str((e.get("application") or {}).get("status", "-") if isinstance(e.get("application"), dict) else e.get("application") or "-"), "muted")], e)
            for e in entries]
    return View(lines, cols, rows, lambda e: [kv(k, v) for k, v in e.items() if not isinstance(v, (dict, list))])


def _ev_export(data, ui):
    keys = [k for k in data if not k.startswith("_") and k not in ("export", "copy") and (data[k] or {}).get("ok")]
    lines = [kv("Destination", str(sources.EXPORT_DIR)), kv("Formats", "JSON (mq.dashboard-export.v1) + Markdown"),
             kv("Sources included", f"{len(keys)} with data"), kv("Excluded", "hostname, pending sources"),
             L(S("Credential patterns are redacted before writing.", "muted")), []]
    export = data.get("export")
    if export and export.get("ok"):
        lines += [kv("Last export", export.get("at")), kv("  JSON", export["data"]["json"]), kv("  Markdown", export["data"]["markdown"])]
    elif export:
        lines.append(L(St("FAIL"), S("  " + export.get("error", ""), "muted")))
    return View(lines, [Col("Action", 40)], [([S("Export evidence bundle (asks first)")], None)],
                enter=lambda _: {"kind": "export"})


def _issue_view(data, cols_kind: str):
    issues = detect_issues(data)
    if cols_kind == "plan":
        issues = [i for i in issues if i["command"]]
    cols = [Col("Severity", 10), Col("Component", 22), Col("Issue", 40, 1)]
    if cols_kind == "plan":
        cols = [Col("#", 3), Col("Risk", 18, 1), Col("Command", 44)]
        rows = [([S(str(n + 1), "muted"), S(i["risk"], "warn" if "medium" in i["risk"] else "muted"), S(i["command"])], i)
                for n, i in enumerate(issues)]
    else:
        rows = [([St(i["severity"]), S(i["component"]), S(i["title"])], i) for i in issues]
    return issues, cols, rows


def _repair_overview(data, ui):
    issues = detect_issues(data)
    counts = {}
    for i in issues:
        counts[i["severity"]] = counts.get(i["severity"], 0) + 1
    planned = sum(1 for i in issues if i["command"])
    lines = [L(*[x for sev in ("FAIL", "WARN", "STALE", "UNVERIFIED", "INFO")
                 for x in (St(sev), S(f" {counts.get(sev, 0)}   ", "muted"))]), [],
             L(S("WORKFLOW", "title"))]
    steps = (("DETECT", f"{len(issues)} issues from {sum(1 for k in data if not k.startswith('_'))} sources", "pass"),
             ("ANALYZE", "cross-source rules (Analysis tab)", "pass"),
             ("FIX PLAN", f"{planned} with a proposed command (Fix Plan tab)", "pass"),
             ("PREVIEW", "Enter on a Fix Plan row shows exactly what would run", "pass"),
             ("OPERATOR APPROVAL", "you decide; nothing proceeds without you", "warn"),
             ("APPLY", "in your own terminal; the dashboard never executes fixes", "muted"),
             ("VALIDATE", "each item names its verify command", "info"),
             ("RECORD EVIDENCE", "R refreshes sources; Evidence > Export writes a bundle", "info"))
    for n, (name, detail, kind) in enumerate(steps):
        lines.append(L(S(f"  {'▼' if n else '●'} {name:<18}", kind), S(detail, "muted")))
    lines += [[], L(S("Automatic repair: ", "muted"), St("DISABLED"))]
    return View(lines)


def _repair_issues(data, ui):
    issues, cols, rows = _issue_view(data, "issues")
    if not issues:
        return View([L(St("PASS"), S("  no issues detected in the collected sources", "muted"))])
    return View([], cols, rows, lambda i: [kv("Severity", i["severity"]), kv("Component", i["component"]),
                                           kv("Evidence", i["evidence"]), [], L(S(i["analysis"]))])


def _repair_analysis(data, ui):
    issues, cols, rows = _issue_view(data, "issues")
    if not issues:
        return View([L(St("PASS"), S("  nothing to analyse", "muted"))])

    def detail(i):
        return [L(S("ROOT CAUSE", "title")), L(S(i["analysis"])), [], kv("Affected components", ", ".join(i["affected"])),
                kv("Evidence source", i["evidence"]), kv("Proposed fix", i["command"] or "inspect manually; no safe one-liner known"),
                kv("Risk", i["risk"]), kv("Reversible", i["reversible"]), kv("Verify with", i["verify"])]
    return View([], cols, rows, detail)


def _repair_plan(data, ui):
    issues, cols, rows = _issue_view(data, "plan")
    if not issues:
        open_issues = len(detect_issues(data))
        if open_issues:
            return View([L(St("INFO"), S(f"  {open_issues} issue(s), none with a safe one-line command; see Issues", "muted"))])
        return View([L(St("PASS"), S("  no issues, no proposed actions", "muted"))])

    def detail(i):
        return [L(S("PREVIEW", "title")), L(S("Would run (in your terminal, not here):", "muted")), L(S("  $ " + i["command"], "accent")), [],
                kv("Why", i["title"]), kv("Risk", i["risk"]), kv("Reversible", i["reversible"]),
                kv("Then verify", i["verify"]), [], L(S("Enter copies the command to the clipboard after you confirm.", "muted"))]
    return View([L(S("Ordered by severity. Every action is manual-review.", "muted"))], cols, rows, detail,
                enter=lambda i: {"kind": "copy", "text": i["command"]})


def _repair_history(data, ui):
    lines = [kv("Repair log", "UNAVAILABLE (no repair evidence source exists yet)"), [], L(S("Evidence exports", "title"))]
    files = sorted(sources.EXPORT_DIR.glob("*.json"))[-10:] if sources.EXPORT_DIR.is_dir() else []
    lines += [L(S(f"  {p.name}", "muted")) for p in reversed(files)] or [L(S("  none yet", "muted"))]
    return View(lines)


def _repair_settings(data, ui):
    return View([kv("Automatic repair", "DISABLED"), kv("Apply location", "operator terminal only"),
                 kv("Clipboard copy", "asks first"), kv("Source timeout", f"{sources.TIMEOUT}s per command"),
                 [], L(S("Detection rules", "title"))] +
                [L(S(f"  · {r}", "muted")) for r in (
                    "doctor fix-plan actions", "stack verification not verified / dirty checkout",
                    "provenance component disagrees", "launchd service not running",
                    "scheduled job non-zero last exit (143 = restart, ignored)", "invalid routing records",
                    "feedback health degraded", "mq-mcp orchestration contract failures",
                    "stale mqobsidian inbox", "Ollama API unreachable", "any source unavailable")] +
                [[], L(S("Settings are fixed in code; changing them is a reviewed PR, not a toggle.", "muted"))])


def _gh_repos(data):
    gh = get(data, "github")
    return (gh or {}).get("repos") or []


def _gh_overview(data, ui):
    lines = [L(S("gh auth ", "muted"), St((get(data, "gh_auth") or {}).get("status", "UNAVAILABLE")))]
    if not get(data, "github"):
        return View(lines + [missing(data, "github")])
    by_name = {r.get("github_repo") or r.get("name"): r for r in repos(data)}
    cols = [Col("Repository", 17), Col("Open PRs", 9), Col("Latest release", 15, 1), Col("CI", 11)]
    rows = []
    for r in _gh_repos(data):
        prs = r.get("prs")
        rels = r.get("releases") or []
        open_n = "-" if prs is None else str(sum(p.get("state") == "OPEN" for p in prs))
        rows.append(([S(r["repo"]), S(open_n, "warn" if open_n not in ("-", "0") else "muted"),
                      S(rels[0]["tagName"] if rels else "none", "muted"),
                      St(ci_status(by_name[r["repo"]]) if r["repo"] in by_name else "UNAVAILABLE")], r))
    return View(lines, cols, rows, lambda r: [kv("PR source", "OK" if r.get("prs") is not None else r.get("pr_error")),
                                              kv("Release source", "OK" if r.get("releases") is not None else r.get("release_error"))])


def _gh_prs(data, ui):
    if not get(data, "github"):
        return View([missing(data, "github")])
    prs = sorted(((r["repo"], p) for r in _gh_repos(data) for p in r.get("prs") or []),
                 key=lambda x: (x[1].get("state") != "OPEN", -(parse_time(x[1].get("updatedAt")) or datetime.min.replace(tzinfo=timezone.utc)).timestamp()))
    cols = [Col("Repository", 16, 1), Col("#", 5), Col("State", 7), Col("Updated", 11, 2), Col("Title", 40)]
    rows = [([S(repo, "muted"), S(str(p.get("number"))), St("DRAFT" if p.get("isDraft") else p.get("state")),
              S(short_time(p.get("updatedAt")), "muted"), S(p.get("title", ""))], (repo, p)) for repo, p in prs]
    return View([L(S("Open first, then most recently updated (last 8 per repo).", "muted"))], cols, rows,
                lambda x: [kv("Repository", x[0])] + [kv(k, v) for k, v in x[1].items()])


def _gh_ci(data, ui):
    rows_data = scope_rows(data)
    if not rows_data:
        return View([missing(data, "stack")])
    cols = [Col("Repository", 17), Col("Check", 32), Col("Status", 8), Col("Completed", 10, 1)]
    rows = [([S(s["repo"]), S(s["scope"]), St(s["status"]), S(age(s["completed"]), "muted")], s) for s in rows_data]
    return View([L(S("Exact-HEAD check runs. Green checks on stale evidence show STALE, not PASS.", "muted"))],
                cols, rows, lambda s: [kv(k, v) for k, v in s.items()])


def _gh_releases(data, ui, limit_per_repo: int = 1):
    if not get(data, "github"):
        return View([missing(data, "github")])
    items = sorted(((rel.get("publishedAt", ""), r["repo"], rel) for r in _gh_repos(data)
                    for rel in (r.get("releases") or [])[:limit_per_repo]), key=lambda x: x[0], reverse=True)
    cols = [Col("Published", 12), Col("Repository", 17), Col("Tag", 12), Col("Flags", 16, 1)]
    rows = [([S(short_time(when), "muted"), S(repo), S(rel.get("tagName")),
              S(" ".join(f for f, on in (("latest", rel.get("isLatest")), ("draft", rel.get("isDraft")),
                                          ("pre", rel.get("isPrerelease"))) if on), "info")], (repo, rel)) for when, repo, rel in items]
    return View([], cols, rows, lambda x: [kv("Repository", x[0])] + [kv(k, v) for k, v in x[1].items()])


def compat_lines(data: dict) -> list:
    compat = get(data, "compatibility")
    if not compat:
        return [missing(data, "compatibility")]
    lines = [L(S("Dependency compatibility ", "title"), St(str(compat.get("status", "-")).upper()),
               S(f"  mode {compat.get('mode')} · {len(compat.get('findings') or [])} findings", "muted"))]
    for pair in compat.get("relationships") or []:
        lines.append(L(S("  "), St(f"{str(pair.get('status', '-')).upper():<5}"),
                       f" {pair.get('producer')} → {pair.get('consumer')} ({pair.get('subject')})"))
    return lines


def _gh_compat(data, ui):
    if not get(data, "github"):
        return View(compat_lines(data) + [[], missing(data, "github")])
    by_name = {r.get("github_repo") or r.get("name"): r for r in repos(data)}
    cols = [Col("Repository", 17), Col("Declared", 9), Col("Release", 10), Col("State", 11)]
    rows = []
    for r in _gh_repos(data):
        declared = str((by_name.get(r["repo"]) or {}).get("version") or "-")
        rels = r.get("releases") or []
        tag = rels[0]["tagName"] if rels else ""
        state = "UNRELEASED" if not tag else ("MATCH" if tag.lstrip("v") == declared else "DRIFT")
        rows.append(([S(r["repo"]), S(declared, "muted"), S(tag or "-", "muted"), St(state)], r))
    return View(compat_lines(data) +
                [L(S("Declared VERSION vs latest GitHub release. DRIFT is unreleased work or a missed tag.", "muted"))],
                cols, rows, lambda r: [kv("Releases", ", ".join(x["tagName"] for x in r.get("releases") or []) or "none")])


def next_run(calendar, now: datetime | None = None) -> str:
    """Next StartCalendarInterval occurrence for Hour/Minute entries."""
    if not calendar:
        return "-"
    now = now or datetime.now()
    entries = calendar if isinstance(calendar, list) else [calendar]
    candidates = []
    for entry in entries:
        if set(entry) - {"Hour", "Minute"}:
            return "see plist"
        at = now.replace(hour=entry.get("Hour", now.hour), minute=entry.get("Minute", 0), second=0, microsecond=0)
        if at <= now:
            at += timedelta(days=1) if "Hour" in entry else timedelta(hours=1)
        candidates.append(at)
    return min(candidates).strftime("%m-%d %H:%M")


def schedule_text(job: dict) -> str:
    if job.get("calendar"):
        entries = job["calendar"] if isinstance(job["calendar"], list) else [job["calendar"]]
        return "daily " + ",".join(f"{e.get('Hour', '*'):02}:{e.get('Minute', 0):02}" if isinstance(e.get("Hour"), int)
                                   else f"*:{e.get('Minute', 0):02}" for e in entries)
    if job.get("interval"):
        return f"every {job['interval']}s"
    if job.get("keep_alive"):
        return "keep-alive"
    return "on demand"


def _auto_rows(data):
    cols = [Col("Job", 26), Col("Schedule", 18, 1), Col("State", 12), Col("Last exit", 14), Col("Next run", 12, 2)]
    rows = []
    for j in get(data, "jobs") or []:
        code = str(j.get("last_exit") or "-")
        kind = "pass" if code in ("0", "(never exited)") else ("muted" if code in ("-", "143") else "fail")
        rows.append(([S(j["label"]), S(schedule_text(j), "muted"), St(j["state"].upper()), S(code, kind),
                      S(next_run(j.get("calendar")), "muted")], j))
    return cols, rows


def _job_detail(j):
    return [kv("Program", j.get("program")), kv("Runs", j.get("runs")), kv("Loaded", j.get("loaded")),
            kv("Run at load", j.get("run_at_load")), kv("stdout", j.get("stdout")), kv("stderr", j.get("stderr"))]


def _auto_overview(data, ui):
    if not get(data, "jobs"):
        return View([missing(data, "jobs")])
    cols, rows = _auto_rows(data)
    return View([L(S("launchd owns scheduling; the dashboard only reads plists and launchctl state.", "muted"))] + recent_results(data),
                cols, rows, _job_detail)


def _auto_jobs(data, ui):
    if not get(data, "jobs"):
        return View([missing(data, "jobs")])
    cols, rows = _auto_rows(data)
    return View([], cols, rows, _job_detail)


def _auto_history(data, ui):
    snaps = get(data, "snapshots")
    if not snaps:
        return View([missing(data, "snapshots")])
    # Key on strings only: same-minute entries would otherwise compare dicts.
    items = sorted(((e["mtime"], kind, e) for kind, entries in snaps.items() for e in entries),
                   key=lambda item: (item[0], item[1], item[2].get("file", "")), reverse=True)
    cols = [Col("Written", 17), Col("Kind", 19), Col("Status", 22), Col("File", 26, 1)]
    rows = [([S(when.replace("T", " "), "muted"), S(kind), St(e["status"] or "-"), S(e["file"], "muted")], e) for when, kind, e in items]
    return View([L(S(f"~/mq-evidence snapshots ({len(rows)})", "muted"))], cols, rows, lambda e: [kv(k, v) for k, v in e.items()])


def _auto_failures(data, ui):
    jobs = get(data, "jobs")
    if jobs is None:
        return View([missing(data, "jobs")])
    failing = [j for j in jobs if str(j.get("last_exit")) not in ("0", "143", "(never exited)", "")]
    lines = [L(St("PASS" if not failing else "WARN"), S(f"  {len(failing)} job(s) with a failing last exit", "muted"))]
    for j in failing:
        lines.append(L(f"  {j['label']}", S(f"  exit {j['last_exit']}", "fail")))
    err = next((j.get("stderr") for j in jobs if j.get("stderr")), "")
    lines += [[], L(S(f"Error log tail  {err or '-'}", "title"))]
    lines += [L(S(x, "muted")) for x in sources.read_tail(err, 15)] or [L(S("(empty)", "muted"))]
    return View(lines)


KEYS = (("↑ ↓", "previous / next row, or scroll"), ("← →", "previous / next tab (Home: move panel focus)"),
        ("Enter", "open panel / run the row's action (always asks first)"), ("Esc / Backspace", "back one level"),
        ("Tab / Shift-Tab", "switch panel focus"), ("1–8", "jump to section"), ("0", "Home"), ("9", "Evidence > Export"),
        ("R", "refresh all sources"), ("H", "help"), ("M", "open mongoTerminal, return on exit"),
        ("/", "search / filter rows (Esc clears)"), ("P", "cycle History period"), ("Q", "quit"))


def _help_keys(data, ui):
    return View([L(S(f"{k:<18}", "accent"), d) for k, d in KEYS] + [[], L(S("Mouse input is disabled by design.", "muted"))])


def _help_status(data, ui):
    rows = (("PASS", "measured now and within freshness limits"), ("WARN", "measured, needs attention"),
            ("FAIL", "measured failure"), ("STALE", "was green, evidence is older than its freshness window"),
            ("UNVERIFIED", "no evidence either way"), ("UNTESTED", "available but not exercised (e.g. OpenAI before test)"),
            ("UNAVAILABLE", "source failed or does not exist"), ("LOADING", "source still running"))
    return View([L(St(f"{k:<12}"), S(f" {d}", "muted")) for k, d in rows])


def _help_sources(data, ui):
    cols = [Col("Source", 20), Col("Status", 12), Col("ms", 7, 1), Col("Command", 30, 2)]
    keys = list(sources.source_table()) + ["github"]
    rows = []
    for key in keys:
        env = data.get(key) or {}
        status = "LOADING" if loading(data, key) else ("PASS" if env.get("ok") else "UNAVAILABLE")
        rows.append(([S(key), St(status), S(str(env.get("elapsed_ms", "-")), "muted"), S(source_label(key), "muted")], key))
    return View([], cols, rows, lambda k: [kv("Command", source_label(k)), kv("Collected", (data.get(k) or {}).get("at")),
                                           kv("Error", (data.get(k) or {}).get("error") or "-")])


def _help_safety(data, ui):
    return View([L(S(x)) for x in (
        "· Read-only by default: commands run as argument lists, no shell, bounded timeouts.",
        "· Two writes exist, both after an explicit y: evidence export and clipboard copy.",
        "· One network test exists (OpenAI), only after an explicit y.",
        "· No restarts, installs, promotions or repairs are executed by the dashboard.",
        "· API keys are never read or shown; log lines are redacted.",
        "· Missing data shows UNAVAILABLE, never PASS.",
        "· Existing mqlaunch and mongoTerminal are unchanged; M opens mongoTerminal.")])


_BUILDERS = {
    ("Repositories", "Overview"): _repos_overview, ("Repositories", "Provenance"): _repos_provenance,
    ("MCP Services", "Overview"): _mcp_overview, ("MCP Services", "Services"): _mcp_services,
    ("MCP Services", "Logs"): _mcp_logs, ("MCP Services", "Tool Surface"): _mcp_tools,
    ("MCP Services", "Compatibility"): _mcp_compat, ("MCP Services", "Diagnostics"): _mcp_diag,
    ("AI Models", "Overview"): _ai_overview, ("AI Models", "Ollama Models"): _ai_models,
    ("AI Models", "Running Models"): _ai_running, ("AI Models", "OpenAI"): _ai_openai,
    ("AI Models", "Routing"): _ai_routing, ("AI Models", "Diagnostics"): _ai_diag,
    ("Evidence & Learning", "Overview"): _ev_overview, ("Evidence & Learning", "Routing"): _ev_routing,
    ("Evidence & Learning", "Hybrid Retrieval"): _ev_hybrid, ("Evidence & Learning", "Memory"): _ev_memory,
    ("Evidence & Learning", "History"): _ev_history, ("Evidence & Learning", "Export"): _ev_export,
    ("Repair Planner", "Overview"): _repair_overview, ("Repair Planner", "Issues"): _repair_issues,
    ("Repair Planner", "Analysis"): _repair_analysis, ("Repair Planner", "Fix Plan"): _repair_plan,
    ("Repair Planner", "History"): _repair_history, ("Repair Planner", "Settings"): _repair_settings,
    ("GitHub & Releases", "Overview"): _gh_overview, ("GitHub & Releases", "Pull Requests"): _gh_prs,
    ("GitHub & Releases", "CI Checks"): _gh_ci, ("GitHub & Releases", "Releases"): _gh_releases,
    ("GitHub & Releases", "Compatibility"): _gh_compat,
    ("GitHub & Releases", "History"): lambda d, u: _gh_releases(d, u, limit_per_repo=5),
    ("Automation", "Overview"): _auto_overview, ("Automation", "Jobs"): _auto_jobs,
    ("Automation", "History"): _auto_history, ("Automation", "Failures"): _auto_failures,
    ("Help", "Keys"): _help_keys, ("Help", "Status"): _help_status,
    ("Help", "Sources"): _help_sources, ("Help", "Safety"): _help_safety,
}


def export_markdown(data: dict) -> str:
    """Human-readable summary written next to the JSON export."""
    out = ["# MQ Dashboard export", "", f"Collected: {data.get('_collected_at', '-')}", "", "## Stack health", "",
           "| Card | Value | Status |", "| --- | --- | --- |"]
    out += [f"| {t} | {v} | {s} |" for t, v, s, _ in health_cards(data)]
    out += ["", "## Issues", ""]
    issues = detect_issues(data)
    out += [f"* {i['severity']} {i['component']}: {i['title']}" for i in issues] or ["* none"]
    out += ["", "## Sources", "", "| Source | OK | Command |", "| --- | --- | --- |"]
    out += [f"| {k} | {(data.get(k) or {}).get('ok')} | `{source_label(k)}` |"
            for k in list(sources.source_table()) + ["github"]]
    return "\n".join(out) + "\n"
