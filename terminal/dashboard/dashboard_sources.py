"""Read-only data sources for MQ Dashboard 2.0.

Every source is an existing MQ command, a local file, or a localhost HTTP
endpoint. Commands run as argument lists (never a shell) with bounded
timeouts. Each result is wrapped in an envelope so the views can tell
"measured", "failed" and "not collected yet" apart; missing data is never
treated as success.

Writes are limited to two operator-confirmed actions defined at the bottom
(export to ~/mq-evidence/dashboard-export and copy to the clipboard).
"""
from __future__ import annotations

import json
import os
import platform
import plistlib
import re
import shutil
import socket
import subprocess
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()
REPO_ROOT = Path(__file__).resolve().parents[2]
AGENT_DIR = Path(os.environ.get("MQ_AGENT_DIR", str(HOME / "mq-agent")))
EVIDENCE_DIR = HOME / "mq-evidence"
EXPORT_DIR = EVIDENCE_DIR / "dashboard-export"
LAUNCH_AGENTS = HOME / "Library" / "LaunchAgents"
OLLAMA_URL = "http://127.0.0.1:11434"
TIMEOUT = 15

# launchd label, display name, port
SERVICES = (("se.mq.mcp", "mq-mcp", 8765), ("se.mq.image", "mq-image-analyze", 8766))

# Token-shaped values only: a word boundary and a realistic minimum length keep
# ordinary words ("task-runner", "feat/risk-…", "API_KEY: missing") intact.
_TOKEN = r"[A-Za-z0-9._~+/=-]"
_SECRET_PATTERNS = (
    (re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"), "[REDACTED]"),
    (re.compile(r"(?<![A-Za-z0-9])(?:gh[pousr]_|github_pat_)[A-Za-z0-9_]{20,}"), "[REDACTED]"),
    (re.compile(r"(?i)(bearer\s+)" + _TOKEN + r"{16,}"), r"\1[REDACTED]"),
    (re.compile(r"(?i)((?:api[_-]?key|token|secret|password)[\"']?\s*[=:]\s*[\"']?)" + _TOKEN + r"{16,}"),
     r"\1[REDACTED]"),
)


def redact(text: str) -> str:
    """Mask credential-shaped substrings before anything reaches the screen."""
    for pattern, replacement in _SECRET_PATTERNS:
        text = pattern.sub(replacement, text)
    return text


def _run(args: list[str], cwd: Path | None, timeout: int) -> tuple[int, str, str]:
    # Wide COLUMNS keeps Rich-formatted text output from hard-wrapping at 80.
    env = dict(os.environ, COLUMNS="200", NO_COLOR="1")
    try:
        result = subprocess.run(args, cwd=str(cwd) if cwd else None, text=True,
                                capture_output=True, timeout=timeout, check=False,
                                stdin=subprocess.DEVNULL, env=env)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return -1, "", type(exc).__name__
    return result.returncode, result.stdout.strip(), result.stderr.strip()


def run_readonly(args: list[str], *, cwd: Path | None = None, timeout: int = TIMEOUT) -> tuple[bool, str]:
    """Execute a known read-only command; never invoke a shell."""
    code, out, err = _run(args, cwd, timeout)
    if code == 0:
        return True, out
    return False, redact((err or out or "exit %d" % code)[-400:])


def run_json(args: list[str], *, cwd: Path | None = None, timeout: int = TIMEOUT) -> dict:
    """Parse stdout even on a non-zero exit: MQ gates exit 1 on WARN but still report."""
    code, out, err = _run(args, cwd, timeout)
    value, error = parse_json_object(out) if out else (None, "")
    if value is None:
        raise SourceError(redact((err or error or "exit %d" % code)[-400:]))
    if value.get("ok") is False and value.get("error"):
        raise SourceError(redact(str(value["error"])))
    return value


def parse_json_object(output: str) -> tuple[dict | None, str]:
    try:
        value = json.loads(output)
    except ValueError:
        return None, "invalid JSON"
    if not isinstance(value, dict):
        return None, "unexpected JSON"
    return value, ""


def agent_command() -> list[str]:
    explicit = os.environ.get("MQ_AGENT_BIN")
    if explicit:
        return [explicit]
    venv = AGENT_DIR / ".venv" / "bin" / "mq-agent"
    if venv.exists():
        return [str(venv)]
    found = shutil.which("mq-agent")
    if found:
        return [found]
    return [shutil.which("uv") or "/opt/homebrew/bin/uv", "run", "mq-agent"]


def agent_json(*args: str, timeout: int = TIMEOUT) -> dict:
    return run_json(agent_command() + list(args),
                    cwd=AGENT_DIR if AGENT_DIR.exists() else None, timeout=timeout)


def script_json(script: str, *args: str) -> dict:
    return run_json(["/bin/bash", str(REPO_ROOT / script), *args], timeout=30)


def http_json(path: str, *, timeout: float = 2.0) -> dict:
    """GET against the local Ollama API only."""
    try:
        with urllib.request.urlopen(OLLAMA_URL + path, timeout=timeout) as response:
            value = json.loads(response.read().decode("utf-8", "replace"))
    except (urllib.error.URLError, OSError, ValueError) as exc:
        raise SourceError("unreachable: " + type(exc).__name__) from None
    if not isinstance(value, dict):
        raise SourceError("unexpected JSON")
    return value


class SourceError(Exception):
    pass


# ---------------------------------------------------------------- collectors

def collect_services() -> list[dict]:
    """launchd state, listening port and process start for the MQ services."""
    services = []
    for label, name, port in SERVICES:
        ok, output = run_readonly(["launchctl", "print", f"gui/{os.getuid()}/{label}"], timeout=4)
        info = launchctl_fields(output) if ok else {}
        listen_ok, listen = run_readonly(["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"], timeout=4)
        pid = info.get("pid")
        started = ""
        if pid:
            ps_ok, ps_out = run_readonly(["ps", "-o", "lstart=", "-p", pid], timeout=3)
            started = ps_out if ps_ok else ""
        plist = read_plist(LAUNCH_AGENTS / f"{label}.plist")
        running = info.get("state") == "running" and listen_ok and bool(listen)
        services.append({
            "label": label, "name": name, "port": port,
            "state": "RUNNING" if running else ("DOWN" if ok else "UNAVAILABLE"),
            "launchd_state": info.get("state", "not loaded" if not ok else "unknown"),
            "listening": bool(listen_ok and listen),
            "pid": pid or "", "runs": info.get("runs", ""),
            "last_exit": info.get("last exit code", ""),
            "started": started,
            "launch_agent": str(LAUNCH_AGENTS / f"{label}.plist") if plist else "",
            "program": redact(" ".join(plist.get("ProgramArguments", []))) if plist else "",
            "stdout": info.get("stdout path", plist.get("StandardOutPath", "") if plist else ""),
            "stderr": info.get("stderr path", plist.get("StandardErrorPath", "") if plist else ""),
        })
    return services


def launchctl_fields(output: str) -> dict:
    """First-level `key = value` pairs from `launchctl print` (indent of one tab)."""
    fields: dict = {}
    for line in output.splitlines():
        if line.startswith("\t") and not line.startswith("\t\t") and " = " in line:
            key, _, value = line.strip().partition(" = ")
            fields.setdefault(key, value)
    return fields


def read_plist(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
        return value if isinstance(value, dict) else {}
    except (OSError, plistlib.InvalidFileException, ValueError):
        return {}


def collect_jobs() -> list[dict]:
    """Scheduled MQ LaunchAgents and their last observed result."""
    jobs = []
    for path in sorted(LAUNCH_AGENTS.glob("se.mq.*.plist")):
        plist = read_plist(path)
        label = plist.get("Label", path.stem)
        ok, output = run_readonly(["launchctl", "print", f"gui/{os.getuid()}/{label}"], timeout=4)
        info = launchctl_fields(output) if ok else {}
        jobs.append({
            "label": label,
            "loaded": ok,
            "state": info.get("state", "not loaded"),
            "last_exit": info.get("last exit code", ""),
            "runs": info.get("runs", ""),
            "program": redact(" ".join(plist.get("ProgramArguments", []))),
            "calendar": plist.get("StartCalendarInterval"),
            "interval": plist.get("StartInterval"),
            "keep_alive": bool(plist.get("KeepAlive")),
            "run_at_load": bool(plist.get("RunAtLoad")),
            "stdout": plist.get("StandardOutPath", ""),
            "stderr": plist.get("StandardErrorPath", ""),
        })
    return jobs


def collect_mcp() -> dict:
    """mq-agent mcp status, with tool specs reduced to their safety flags."""
    raw = agent_json("mcp", "status", "--json", timeout=25)
    servers = {}
    for name, server in (raw.get("servers") or {}).items():
        tools = []
        for spec in server.get("specs") or []:
            text = str(spec)
            tool = re.search(r"name='([^']+)'", text)
            klass = re.search(r"safety_class='([^']+)'", text)
            tools.append({"name": tool.group(1) if tool else "?",
                          "safety_class": klass.group(1) if klass else "unknown",
                          "write_capable": "write_capable=True" in text,
                          "dangerous": "dangerous=True" in text})
        contract_text = ""
        contract = server.get("contract")
        if isinstance(contract, list) and contract and isinstance(contract[0], list):
            contract_text = "\n".join(str(part.get("text", "")) for part in contract[0] if isinstance(part, dict))
        elif isinstance(contract, str):
            contract_text = contract
        servers[name] = {"available": server.get("available"), "endpoint": server.get("endpoint"),
                         "tools": server.get("tools"), "tool_specs": tools,
                         "contract": contract_text,
                         "semantic_memory_count": server.get("semantic_memory_count")}
    return {"servers": servers}


def collect_ollama() -> dict:
    """Ollama over its local HTTP API. Unlike `ollama list`, never starts a server."""
    version = http_json("/api/version").get("version", "")
    tags = http_json("/api/tags").get("models") or []
    running = http_json("/api/ps").get("models") or []
    return {"version": version, "models": tags, "running": running}


def collect_memory() -> dict:
    """Physical memory and an approximate free figure from vm_stat."""
    ok, total = run_readonly(["sysctl", "-n", "hw.memsize"], timeout=3)
    vm_ok, vm = run_readonly(["vm_stat"], timeout=3)
    if not ok:
        raise SourceError(total)
    page = 16384
    pages: dict = {}
    if vm_ok:
        size = re.search(r"page size of (\d+) bytes", vm)
        page = int(size.group(1)) if size else page
        for line in vm.splitlines()[1:]:
            key, _, value = line.partition(":")
            if value.strip().rstrip(".").isdigit():
                pages[key.strip()] = int(value.strip().rstrip("."))
    free = (pages.get("Pages free", 0) + pages.get("Pages inactive", 0)) * page if vm_ok else None
    return {"total_bytes": int(total), "approx_available_bytes": free}


def collect_gh_auth() -> dict:
    ok, output = run_readonly(["gh", "auth", "status"], timeout=6)
    return {"status": "AUTHENTICATED" if ok else "UNAVAILABLE", "detail": "" if ok else output[:160]}


def collect_snapshots() -> dict:
    """Evidence snapshots written by the scheduled MQ jobs (read-only)."""
    out: dict = {}
    for name in ("stack-status", "routing-divergence"):
        folder = EVIDENCE_DIR / name
        files = sorted(folder.glob("*.json")) if folder.is_dir() else []
        entries = []
        for path in files[-30:]:
            status = ""
            try:
                value = json.loads(path.read_text())
                status = str(value.get("overall") or value.get("status") or "")
            except (OSError, ValueError):
                status = "INVALID"
            entries.append({"file": path.name, "status": status,
                            "mtime": datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="minutes")})
        out[name] = entries
    return out


def collect_host() -> dict:
    """Identity for the header panel. Shown on screen only; never exported."""
    boot = None
    ok, out = run_readonly(["sysctl", "-n", "kern.boottime"], timeout=3)
    match = re.search(r"sec = (\d+)", out) if ok else None
    if match:
        boot = int(match.group(1))
    ip = ""
    ok, iface = run_readonly(["route", "-n", "get", "default"], timeout=3)
    found = re.search(r"interface:\s*(\S+)", iface) if ok else None
    if found:
        ip_ok, ip_out = run_readonly(["ipconfig", "getifaddr", found.group(1)], timeout=3)
        ip = ip_out if ip_ok else ""
    try:
        version = (REPO_ROOT / "VERSION").read_text().strip()
    except OSError:
        version = ""
    return {"host": socket.gethostname().split(".")[0], "macos": platform.mac_ver()[0] or platform.system(),
            "python": platform.python_version(), "user": os.environ.get("USER", ""),
            "repo": "~/" + REPO_ROOT.name if REPO_ROOT.parent == HOME else str(REPO_ROOT),
            "ip": ip, "boot_epoch": boot, "version": version}


def github_owner() -> str:
    ok, url = run_readonly(["git", "-C", str(REPO_ROOT), "remote", "get-url", "origin"], timeout=3)
    match = re.search(r"github\.com[:/]([^/]+)/", url) if ok else None
    return match.group(1) if match else ""


def collect_github(repos: list[str]) -> dict:
    """Pull requests and releases per repo via `gh` (network, read-only)."""
    owner = github_owner()
    if not owner:
        raise SourceError("cannot resolve GitHub owner from origin remote")

    def one(repo: str) -> dict:
        slug = f"{owner}/{repo}"
        pr_ok, prs = run_readonly(["gh", "pr", "list", "--repo", slug, "--state", "all", "--limit", "8",
                                   "--json", "number,title,state,isDraft,updatedAt,headRefName,reviewDecision"], timeout=20)
        rel_ok, rels = run_readonly(["gh", "release", "list", "--repo", slug, "--limit", "5",
                                     "--json", "tagName,publishedAt,isLatest,isDraft,isPrerelease"], timeout=20)
        return {"repo": repo,
                "prs": json.loads(prs) if pr_ok and prs.startswith("[") else None,
                "pr_error": "" if pr_ok else prs[:160],
                "releases": json.loads(rels) if rel_ok and rels.startswith("[") else None,
                "release_error": "" if rel_ok else rels[:160]}

    found: dict = {}
    run_parallel({repo: (lambda r=repo: one(r)) for repo in repos}, 6,
                 lambda key, result: found.__setitem__(key, result))
    results = [found[r]["data"] or {"repo": r, "prs": None, "pr_error": found[r]["error"],
                                    "releases": None, "release_error": found[r]["error"]} for r in repos]
    return {"owner": owner, "repos": results}


def read_tail(path: str, lines: int = 40) -> list[str]:
    """Last lines of a local log, redacted. Reads at most 64 KiB."""
    if not path:
        return []
    try:
        with open(path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            handle.seek(max(0, size - 65536))
            text = handle.read().decode("utf-8", "replace")
    except OSError:
        return []
    return [redact(line) for line in text.splitlines()[-lines:]]


# Each source: key -> (description shown in Help/Diagnostics, callable).
def source_table() -> dict:
    # Fast local sources first: they take worker slots before the slower
    # mq-agent calls, so most cards fill within a fraction of a second.
    return {
        "services": ("launchctl print + lsof + ps", collect_services),
        "jobs": ("~/Library/LaunchAgents/se.mq.*.plist + launchctl print", collect_jobs),
        "ollama": ("Ollama HTTP API 127.0.0.1:11434 (/api/version, /api/tags, /api/ps)", collect_ollama),
        "memory": ("sysctl hw.memsize + vm_stat", collect_memory),
        "auth": ("mqlaunch auth status --json (local, no network)", lambda: script_json("tools/scripts/auth.sh", "status", "--json")),
        "gh_auth": ("gh auth status", collect_gh_auth),
        "doctor": ("mqlaunch doctor --fix-plan --json", lambda: script_json("tools/scripts/doctor.sh", "--fix-plan", "--json")),
        "snapshots": ("~/mq-evidence/{stack-status,routing-divergence}/*.json", collect_snapshots),
        "host": ("hostname, macOS, user, uptime, local IP, VERSION (screen only)", collect_host),
        "stack": ("mq-agent stack status --json", lambda: agent_json("stack", "status", "--json", timeout=45)),
        "provenance": ("mq-agent stack provenance --json", lambda: agent_json("stack", "provenance", "--json", timeout=30)),
        "compatibility": ("mq-agent stack compatibility --json", lambda: agent_json("stack", "compatibility", "--json")),
        "routing": ("mq-agent route readiness --json", lambda: agent_json("route", "readiness", "--json")),
        "divergence": ("mq-agent route divergence --json", lambda: agent_json("route", "divergence", "--json")),
        "route_history": ("mq-agent route history --limit 0 --json", lambda: agent_json("route", "history", "--limit", "0", "--json")),
        "execution": ("mq-agent execution report --json", lambda: agent_json("execution", "report", "--json")),
        "feedback_report": ("mq-agent feedback report --json", lambda: agent_json("feedback", "report", "--json")),
        "feedback_candidates": ("mq-agent feedback candidates --json", lambda: agent_json("feedback", "candidates", "--json")),
        "memory_review": ("mq-agent memory review-status --json", lambda: agent_json("memory", "review-status", "--json")),
        "inbox": ("mq-agent obsidian inbox list --json", lambda: agent_json("obsidian", "inbox", "list", "--json")),
        "model_profiles": ("mq-agent models current --json", lambda: agent_json("models", "current", "--json")),
        "mcp": ("mq-agent mcp status --json", collect_mcp),
    }


def run_parallel(fns: dict, workers: int, on_result) -> None:
    """Run callables on daemon threads, at most `workers` at once, and call
    on_result(key, envelope) as each finishes. Returns once all are done.

    Daemon threads rather than ThreadPoolExecutor: the executor's workers are
    joined at interpreter exit, so quitting would wait out every running
    subprocess (up to the 45s stack timeout).
    """
    gate = threading.Semaphore(max(1, workers))
    threads = []

    def worker(key, fn):
        with gate:
            on_result(key, envelope(fn))

    for key, fn in fns.items():
        thread = threading.Thread(target=worker, args=(key, fn), daemon=True)
        thread.start()
        threads.append(thread)
    for thread in threads:
        thread.join()


def envelope(fn) -> dict:
    started = time.monotonic()
    try:
        data, error = fn(), ""
    except SourceError as exc:
        data, error = None, str(exc) or "failed"
    except Exception as exc:  # a broken source must not take the dashboard down
        data, error = None, f"{type(exc).__name__}: {exc}"[:200]
    return {"ok": data is not None, "data": data, "error": redact(error),
            "elapsed_ms": int((time.monotonic() - started) * 1000),
            "at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}


class Collector:
    """Collects all sources in parallel; the UI renders whatever has arrived."""

    def __init__(self, sources: dict | None = None, workers: int = 8, github: bool = True):
        self.sources = sources if sources is not None else source_table()
        self.workers = workers
        self.github = github
        self.lock = threading.Lock()
        self.results: dict = {}
        self.pending: set = set()
        self.generation = 0

    def start(self) -> None:
        with self.lock:
            self.generation += 1
            generation = self.generation
            self.pending = set(self.sources) | ({"github"} if self.github else set())
        thread = threading.Thread(target=self._run, args=(generation,), daemon=True)
        thread.start()

    def _store(self, generation: int, key: str, result: dict) -> None:
        with self.lock:
            if generation != self.generation:
                return
            self.results[key] = result
            self.pending.discard(key)

    def _run(self, generation: int) -> None:
        # Each result is stored the moment it finishes, so fast sources are not
        # held behind the slow `stack` call.
        stack_done = threading.Event()

        def store(key: str, result: dict) -> None:
            self._store(generation, key, result)
            if key == "stack":
                stack_done.set()

        if "stack" not in self.sources:
            stack_done.set()
        run_parallel({key: fn for key, (_, fn) in self.sources.items()}, self.workers, store)
        if self.github:
            stack_done.wait()
            with self.lock:
                stack = self.results.get("stack", {}).get("data") or {}
            repos = [r.get("github_repo") or r.get("name") for r in stack.get("repos", []) if r.get("exists", True)]
            if repos:
                self._store(generation, "github", envelope(lambda: collect_github(repos)))
            else:
                self._store(generation, "github", {"ok": False, "data": None, "elapsed_ms": 0,
                                                   "error": "no repositories from stack status",
                                                   "at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")})

    def run_action(self, key: str, fn) -> None:
        """Run one operator-requested action in the background."""
        with self.lock:
            self.pending.add(key)

        def target():
            result = envelope(fn)
            with self.lock:
                self.results[key] = result
                self.pending.discard(key)
        threading.Thread(target=target, daemon=True).start()

    def snapshot(self) -> dict:
        with self.lock:
            data = dict(self.results)
            data["_pending"] = sorted(self.pending)
            data["_collected_at"] = max((r.get("at", "") for r in self.results.values()), default="")
        return data

    def wait(self, timeout: float = 120.0) -> dict:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            with self.lock:
                if not self.pending:
                    break
            time.sleep(0.1)
        return self.snapshot()


# ------------------------------------------------- operator-confirmed actions

def openai_test() -> dict:
    """Explicit API request through mqlaunch auth (never shows the key)."""
    started = time.monotonic()
    value = script_json("tools/scripts/auth.sh", "test", "openai", "--json")
    value["round_trip_ms"] = int((time.monotonic() - started) * 1000)
    return value


def export_evidence(data: dict, markdown: str) -> dict:
    """Write the collected snapshot as JSON and Markdown. Operator-confirmed."""
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    clean = {k: v for k, v in data.items() if not k.startswith("_") and k != "host"}
    json_path = EXPORT_DIR / f"{stamp}.json"
    md_path = EXPORT_DIR / f"{stamp}.md"
    json_path.write_text(redact(json.dumps({"schema": "mq.dashboard-export.v1", "exported_at": stamp,
                                            "sources": clean}, indent=2, ensure_ascii=False)) + "\n")
    md_path.write_text(redact(markdown))
    return {"json": str(json_path), "markdown": str(md_path)}


def copy_to_clipboard(text: str) -> dict:
    try:
        subprocess.run(["pbcopy"], input=text, text=True, check=True, timeout=3)
    except (OSError, subprocess.SubprocessError) as exc:
        raise SourceError(type(exc).__name__) from None
    return {"copied": text}
