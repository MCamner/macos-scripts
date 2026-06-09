from __future__ import annotations

import json

BLOCKING_SEVERITIES = {"BLOCKER", "CRITICAL", "RISK"}

_SEVERITY_ORDER = ["BLOCKER", "CRITICAL", "RISK", "HIGH", "MEDIUM", "LOW", "WARNING", "INFO"]


def parse_review_json(text: str) -> list[dict]:
    """Extract findings list from mq-agent review --json output."""
    try:
        data = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return []
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if isinstance(data, dict):
        findings = data.get("findings")
        if isinstance(findings, list):
            return [item for item in findings if isinstance(item, dict)]
        result = data.get("result")
        if isinstance(result, dict):
            return parse_review_json(json.dumps(result))
    return []


def severity_of(item: dict) -> str:
    for key in ("severity", "label", "type", "category"):
        val = item.get(key)
        if val:
            return str(val).upper()
    return "UNSPECIFIED"


def severity_counts(findings: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for f in findings:
        sev = severity_of(f)
        counts[sev] = counts.get(sev, 0) + 1
    return counts


def has_blocking(findings: list[dict]) -> bool:
    return any(severity_of(f) in BLOCKING_SEVERITIES for f in findings)


def render_findings(findings: list[dict]) -> str:
    if not findings:
        return "  No findings."
    lines: list[str] = []
    for item in findings:
        sev = severity_of(item)
        source = str(item.get("file") or item.get("path") or item.get("source") or "")
        line = item.get("line")
        if line and source:
            source = f"{source}:{line}"
        msg = str(item.get("message") or item.get("title") or item.get("summary") or "")
        loc = f"  {source}" if source else ""
        lines.append(f"  [{sev}]{loc}")
        if msg:
            lines.append(f"  {msg}")
        lines.append("")
    return "\n".join(lines).rstrip()


def render_summary(findings: list[dict]) -> str:
    if not findings:
        return "  No findings."
    counts = severity_counts(findings)
    known = [f"{sev} {counts[sev]}" for sev in _SEVERITY_ORDER if sev in counts]
    extra = [f"{k} {v}" for k, v in counts.items() if k not in _SEVERITY_ORDER]
    return "  " + "  ".join(known + extra)
