"""MQ Dashboard 2.0 checks: truth rules, sources, layout and keys (no terminal, no network)."""
import ast
import curses
import json
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

DASH = Path(__file__).resolve().parents[1] / "terminal" / "dashboard"
sys.path.insert(0, str(DASH))

import dashboard_sources as sources  # noqa: E402
import dashboard_views as views  # noqa: E402
import mq_dashboard as dashboard  # noqa: E402


def env(data):
    return {"ok": True, "data": data, "error": "", "elapsed_ms": 1, "at": "2026-10-17 01:00:00"}


def failed(error):
    return {"ok": False, "data": None, "error": error, "elapsed_ms": 1, "at": "2026-10-17 01:00:00"}


def scope(name, status="PASS"):
    return {"name": name, "status": status, "completed_at": "2026-10-16T19:00:00Z", "details_url": "u"}


CONTRACT = ("## Orchestration contract validation — FAIL\n\nChecks: 8 passed, 1 failed, 0 warnings\n"
            "[PASS] profiles/read-only.json: all 6 tools valid\n"
            "[FAIL] profiles/codex.json:mq_route_shadow\n"
            "Profile 'codex' is restricted to Class A/B but includes 'mq_route_shadow' which is Class C.\n")


def fixture():
    """A realistic snapshot shaped like the real mq-agent / launchd / Ollama output."""
    return {
        "stack": env({"overall": "STALE", "checked_at": "2026-10-16T23:00:00Z", "max_age_seconds": 86400, "repos": [
            {"name": "mqlaunch", "github_repo": "macos-scripts", "version": "2.2.0", "branch": "main",
             "commit": "e9bb7f5a" * 5, "dirty": False,
             "verification": {"status": "VERIFIED", "reason": "all-required-checks-passed",
                              "scopes": [scope("Shell syntax check"), scope("Python tests")]}},
            {"name": "mqobsidian", "github_repo": "mqobsidian", "version": "0.4.0", "branch": "main",
             "commit": "6236ffc0" * 5, "dirty": True,
             "verification": {"status": "STALE", "reason": "evidence-older-than-86400s",
                              "scopes": [scope("lint")]}},
        ]}),
        "provenance": env({"components": [
            {"name": "mq-agent", "status": "PASS", "reasons": [], "checkout": {"path": "/x/mq-agent"}},
            {"name": "mq-mcp", "status": "WARN", "reasons": ["RTP001_DIRTY_WORKTREE"], "checkout": {"path": "/x/mq-mcp"}},
        ]}),
        "compatibility": env({"status": "WARN", "mode": "static", "next_action": "",
                              "relationships": [
                                  {"producer": "mq-image-analyze", "consumer": "mq-mcp", "subject": "mcp", "status": "PASS"},
                                  {"producer": "mq-mcp", "consumer": "mq-agent", "subject": "mcp", "status": "WARN"}],
                              "findings": [{"status": "WARN", "detail": "mq-agent pins mcp outside mq-mcp's range"}]}),
        "routing": env({"invalid_records": 0, "automatic_routing_enabled": False, "operator_approval_required": True,
                        "thresholds": {"minimum_observations": 20},
                        "task_classes": {"docs-review": {
                            "recommendation": "AWAITING_OPERATOR_APPROVAL", "eligible": True,
                            "actual": {"observations": 28, "candidate_routes": 2, "window_days": 45.7,
                                       "minimum_samples_per_route": 12},
                            "routes": {"local-shadow": 16, "deterministic-local": 12},
                            "gates": {"minimum_observations": True}}}}),
        "services": env([
            {"label": "se.mq.mcp", "name": "mq-mcp", "port": 8765, "state": "RUNNING", "launchd_state": "running",
             "listening": True, "pid": "77600", "runs": "4", "last_exit": "143", "started": "", "launch_agent": "",
             "program": "", "stdout": "", "stderr": ""},
            {"label": "se.mq.image", "name": "mq-image-analyze", "port": 8766, "state": "DOWN",
             "launchd_state": "not running", "listening": False, "pid": "", "runs": "1", "last_exit": "1",
             "started": "", "launch_agent": "", "program": "", "stdout": "", "stderr": ""},
        ]),
        "mcp": env({"servers": {"mq-mcp": {"available": True, "endpoint": "http://127.0.0.1:8765", "tools": 3,
                                           "contract": CONTRACT, "tool_specs": [
                                               {"name": "read_repo_file", "safety_class": "read-only",
                                                "write_capable": False, "dangerous": False},
                                               {"name": "shell_exec", "safety_class": "subprocess",
                                                "write_capable": True, "dangerous": True}]}}}),
        "jobs": env([
            {"label": "se.mq.mcp", "last_exit": "143", "state": "running", "calendar": None, "interval": None,
             "keep_alive": True, "stderr": ""},
            {"label": "se.mq.evaluate", "last_exit": "1", "state": "not running",
             "calendar": [{"Hour": 8, "Minute": 0}, {"Hour": 20, "Minute": 0}], "interval": None,
             "keep_alive": False, "stderr": ""},
        ]),
        "ollama": env({"version": "0.40.5", "running": [],
                       "models": [{"name": "qwen3:4b-instruct", "size": 2 * 1024 ** 3,
                                   "details": {"parameter_size": "4.0B", "context_length": 262144}}]}),
        "auth": env({"status": "ok", "effective_source": "keychain", "consistency": "not-comparable",
                     "keychain": {"status": "present"}, "process": {"status": "missing"}}),
        "doctor": env({"status": "warn", "source": {"checks": [], "summary": {"ok": 1, "warn": 1, "fail": 0}},
                       "actions": [{"check": "OPENAI_API_KEY", "observed_status": "warn", "observed_detail": "missing",
                                    "command": "mqlaunch auth status", "verify": "mqlaunch doctor --json"}]}),
        "inbox": failed("canonical surface is stale: inbox"),
        "gh_auth": env({"status": "AUTHENTICATED"}),
        "github": env({"owner": "MCamner", "repos": [
            {"repo": "macos-scripts", "prs": [{"number": 282, "title": "layout", "state": "OPEN", "isDraft": False,
                                               "updatedAt": "2026-10-16T20:44:44Z"}],
             "releases": [{"tagName": "v2.2.0", "publishedAt": "2026-10-10T10:00:00Z", "isLatest": True}]},
            {"repo": "mqobsidian", "prs": [], "releases": []}]}),
        "_pending": [],
        "_collected_at": "2026-10-17 01:00:00",
    }


class FakeScreen:
    """Enough of a curses window to render into a character grid."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.grid = [[" "] * w for _ in range(h)]

    def getmaxyx(self):
        return self.h, self.w

    def erase(self):
        self.grid = [[" "] * self.w for _ in range(self.h)]

    def refresh(self):
        pass

    def addnstr(self, y, x, text, n, attr=0):
        if not (0 <= y < self.h and 0 <= x < self.w):
            raise curses.error("out of bounds")
        for i, ch in enumerate(text[:n]):
            if x + i >= self.w:
                raise curses.error("past right edge")
            self.grid[y][x + i] = ch

    def text(self):
        return "\n".join("".join(row) for row in self.grid)


class FakeCollector:
    def __init__(self):
        self.actions, self.refreshes = [], 0

    def run_action(self, key, fn):
        self.actions.append(key)

    def start(self):
        self.refreshes += 1

    def snapshot(self):
        return fixture()


class Python39Compatibility(unittest.TestCase):
    def test_dashboard_parses_as_python_39(self):
        # /usr/bin/python3 on macOS is 3.9; CI runs a newer Python.
        for path in DASH.glob("*.py"):
            ast.parse(path.read_text(), filename=str(path), feature_version=(3, 9))


class StructureTests(unittest.TestCase):
    def test_sections_and_required_tabs(self):
        names = views.SECTION_NAMES
        for required in ("Repositories", "MCP Services", "AI Models", "Evidence & Learning",
                         "Repair Planner", "GitHub & Releases", "Automation", "Help"):
            self.assertIn(required, names)
        tabs = dict(views.SECTIONS)
        self.assertEqual(tabs["Evidence & Learning"],
                         ("Overview", "Routing", "Hybrid Retrieval", "Memory", "History", "Export"))
        self.assertEqual(tabs["Repair Planner"],
                         ("Overview", "Issues", "Analysis", "Fix Plan", "History", "Settings"))
        self.assertEqual(len(tabs["MCP Services"]), 6)
        self.assertEqual(len(tabs["AI Models"]), 6)
        self.assertEqual(len(tabs["GitHub & Releases"]), 6)
        self.assertLessEqual(len(names), 10)

    def test_every_tab_has_a_builder(self):
        for name, tabs in views.SECTIONS:
            for tab in tabs:
                self.assertIn((name, tab), views._BUILDERS, f"{name}/{tab}")


class TruthRules(unittest.TestCase):
    def test_no_data_never_claims_pass(self):
        data = {"_pending": []}
        for title, _value, status, _sub in views.health_cards(data):
            self.assertNotEqual(status, "PASS", title)
        for n, (name, tabs) in enumerate(views.SECTIONS):
            if name == "Help":
                continue  # Help lists the status vocabulary itself
            for t in range(len(tabs)):
                view = views.build_view(n, t, data)
                text = "\n".join(views.text_of(line) for line in view.lines)
                text += "\n".join(views.text_of(cells) for cells, _ in view.rows)
                self.assertNotIn("PASS", text, f"{name}/{tabs[t]}")

    def test_empty_data_is_unverified_not_healthy(self):
        issues = views.detect_issues({"_pending": []})
        self.assertTrue(issues)
        self.assertTrue(all(i["severity"] == "UNVERIFIED" for i in issues))

    def test_pending_sources_show_loading(self):
        data = {"_pending": ["stack", "ollama"]}
        cards = {c[0]: c[2] for c in views.health_cards(data)}
        self.assertEqual(cards["Repositories"], "LOADING")
        self.assertEqual(cards["Local AI"], "LOADING")
        self.assertFalse(any(i["component"] == "source:stack" for i in views.detect_issues(data)))

    def test_stale_repo_turns_green_checks_stale(self):
        rows = views.scope_rows(fixture())
        lint = next(r for r in rows if r["scope"] == "lint")
        self.assertEqual(lint["status"], "STALE")
        cards = {c[0]: c for c in views.health_cards(fixture())}
        self.assertEqual(cards["GitHub CI"][2], "STALE")
        self.assertEqual(cards["Repositories"][1:3], ("1/2", "STALE"))

    def test_installed_model_is_not_running(self):
        cards = {c[0]: c for c in views.health_cards(fixture())}
        self.assertEqual(cards["Local AI"][1], "0 loaded")
        view = views.build_view(3, 2, fixture())
        self.assertIn("not running", views.text_of(view.lines[-1]))

    def test_openai_is_untested_until_explicit_test(self):
        data = fixture()
        self.assertEqual(views.openai_state(data)[0], "UNTESTED")
        data["openai_test"] = env({"status": "ok", "http_status": 200, "round_trip_ms": 300})
        self.assertEqual(views.openai_state(data)[0], "OK")

    def test_security_counts_dangerous_tools_and_contract_failures(self):
        warnings = views.security_warnings(fixture())
        self.assertTrue(any("shell_exec" in w for w in warnings))
        self.assertTrue(any("mq_route_shadow" in w and "Class C" in w for w in warnings))
        cards = {c[0]: c for c in views.health_cards(fixture())}
        self.assertEqual(cards["Security"][2], "WARN")

    def test_compatibility_card_uses_stack_compatibility(self):
        cards = {c[0]: c for c in views.health_cards(fixture())}
        self.assertEqual(cards["Compatibility"][1:3], ("1/2", "WARN"))

    def test_compatibility_findings_become_issues(self):
        issues = [i for i in views.detect_issues(fixture()) if i["component"] == "stack compatibility"]
        self.assertEqual(len(issues), 1)
        self.assertIn("mcp", issues[0]["analysis"])


class RepairPlanner(unittest.TestCase):
    def setUp(self):
        self.issues = views.detect_issues(fixture())

    def find(self, component):
        return [i for i in self.issues if i["component"] == component]

    def test_down_service_gets_manual_restart_with_risk(self):
        issue = self.find("mq-image-analyze")[0]
        self.assertEqual(issue["severity"], "FAIL")
        self.assertIn("launchctl kickstart -k", issue["command"])
        self.assertIn("medium", issue["risk"])

    def test_keychain_explains_doctor_env_warning(self):
        issue = self.find("doctor:OPENAI_API_KEY")[0]
        self.assertEqual(issue["severity"], "INFO")
        self.assertIn("Keychain", issue["analysis"])

    def test_sigterm_exit_is_not_a_job_failure(self):
        self.assertFalse(self.find("se.mq.mcp"))
        self.assertTrue(self.find("se.mq.evaluate"))

    def test_sorted_by_severity_and_stale_inbox_reported(self):
        order = [views._SEVERITY[i["severity"]] for i in self.issues]
        self.assertEqual(order, sorted(order))
        self.assertTrue(any(i["severity"] == "STALE" and i["component"] == "mqobsidian" for i in self.issues))

    def test_fix_plan_only_proposes_never_executes(self):
        view = views.build_view(5, 3, fixture())
        self.assertTrue(view.rows)
        action = view.enter(view.rows[0][1])
        self.assertEqual(action["kind"], "copy")


class Sources(unittest.TestCase):
    def test_redaction_masks_credentials(self):
        # Built at runtime so no credential-shaped literal sits in the repo.
        secrets = ("sk" + "-proj-" + "a1b2c3d4" * 3, "gh" + "p_" + "e5f6g7h8" * 3,
                   "eyJhbGciOiJIUzI1NiJ9.payload.sig", "Zx9Qw8Er7Ty6Ui5Op4As")
        text = sources.redact(f"key {secrets[0]} gh {secrets[1]} Authorization: Bearer {secrets[2]} "
                              f'"api_key": "{secrets[3]}"')
        for secret in secrets:
            self.assertNotIn(secret, text)
        self.assertIn('"api_key": "[REDACTED]', text)

    def test_redaction_leaves_ordinary_text_alone(self):
        for text in ("task-runner-for-docs-review-flows", "feat/risk-review-dashboard-layout",
                     "OPENAI_API_KEY: missing", "context_tokens: unavailable",
                     "export OPENAI_API_KEY=$(/usr/bin/security find-generic-password -w)"):
            self.assertEqual(sources.redact(text), text)

    def test_missing_command_does_not_crash(self):
        ok, output = sources.run_readonly(["/definitely/missing/mq-command"])
        self.assertFalse(ok)
        self.assertTrue(output)

    def test_json_is_read_on_non_zero_exit(self):
        value = sources.run_json([sys.executable, "-c", "import json;print(json.dumps({'status':'warn'}));raise SystemExit(1)"])
        self.assertEqual(value["status"], "warn")

    def test_json_error_payload_is_an_error(self):
        with self.assertRaises(sources.SourceError):
            sources.run_json([sys.executable, "-c", "print('{\"ok\": false, \"error\": \"stale\"}')"])

    def test_envelope_contains_exceptions(self):
        result = sources.envelope(lambda: 1 / 0)
        self.assertFalse(result["ok"])
        self.assertIn("ZeroDivisionError", result["error"])

    def test_collector_with_injected_sources(self):
        collector = sources.Collector({"a": ("a", lambda: {"x": 1}), "b": ("b", lambda: (_ for _ in ()).throw(sources.SourceError("down")))},
                                      github=False)
        collector.start()
        data = collector.wait(10)
        self.assertTrue(data["a"]["ok"])
        self.assertEqual(data["b"]["error"], "down")
        self.assertEqual(data["_pending"], [])

    def test_launchctl_fields_first_level_only(self):
        out = "gui/501/se.mq.mcp = {\n\tstate = running\n\tpid = 77\n\t\tstate = active\n}"
        self.assertEqual(sources.launchctl_fields(out), {"state": "running", "pid": "77"})

    def test_export_writes_json_and_markdown_without_host(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = sources.EXPORT_DIR
            sources.EXPORT_DIR = Path(tmp)
            try:
                data = fixture()
                data["host"] = env({"host": "secret-host"})
                paths = sources.export_evidence(data, views.export_markdown(data))
            finally:
                sources.EXPORT_DIR = original
            exported = json.loads(Path(paths["json"]).read_text())
            self.assertEqual(exported["schema"], "mq.dashboard-export.v1")
            self.assertNotIn("host", exported["sources"])
            self.assertIn("## Issues", Path(paths["markdown"]).read_text())


class Formatting(unittest.TestCase):
    def test_columns_dropped_by_priority_to_fit(self):
        cols = [views.Col("A", 10), views.Col("B", 10, 2), views.Col("C", 10, 1)]
        cells = [views.S("a"), views.S("b"), views.S("c")]
        row = views.text_of(views.format_row(cols, cells, 25))
        self.assertEqual(row, "a" + " " * 10 + "c")  # B (lowest priority) dropped; last column unpadded
        self.assertEqual(views.text_of(views.format_row(cols, cells, 40)).split(), ["a", "b", "c"])
        for width in (5, 25, 40):
            self.assertLessEqual(len(views.text_of(views.format_row(cols, cells, width))), width)

    def test_next_run(self):
        now = datetime(2026, 10, 17, 9, 30)
        self.assertEqual(views.next_run([{"Hour": 8, "Minute": 0}, {"Hour": 20, "Minute": 0}], now), "10-17 20:00")
        self.assertEqual(views.next_run({"Hour": 8, "Minute": 0}, now), "10-18 08:00")
        self.assertEqual(views.next_run({"Weekday": 1, "Hour": 8}, now), "see plist")

    def test_parse_time_variants(self):
        for value in ("2026-10-15T10:02:34.792776437+02:00", "2026-10-16T19:00:00Z", "2026-10-16T19:00:00.03Z"):
            self.assertIsNotNone(views.parse_time(value), value)

    def test_wrap_line_keeps_width(self):
        line = views.L("Label  ", "a very long value that will certainly not fit in the box")
        for part in dashboard.wrap_line(line, 20):
            self.assertLessEqual(len(views.text_of(part)), 20)


class Rendering(unittest.TestCase):
    def render(self, w, h, st):
        screen = FakeScreen(w, h)
        dashboard.draw(screen, dashboard.Theme(False), fixture(), st)
        return screen.text()

    def test_full_home_has_cards_and_panels(self):
        text = self.render(160, 48, dashboard.State())
        for label in ("REPOSITORIES", "GITHUB CI", "MCP SERVICES", "LOCAL AI", "OPENAI API", "SECURITY",
                      "COMPATIBILITY", "EVIDENCE & LEARNING", "RECENT RESULTS", "GITHUB & RELEASES", "QUICK ACTIONS"):
            self.assertIn(label, text)

    def test_compact_home_keeps_every_panel(self):
        st = dashboard.State()
        screen = FakeScreen(80, 24)
        dashboard.draw(screen, dashboard.Theme(False), fixture(), st)
        self.assertIn("HOME (compact)", screen.text())
        lines, starts = dashboard.home_compact_lines(fixture(), st, 76)
        joined = "\n".join(views.text_of(x) for x in lines)
        for label in ("REPOSITORIES", "MCP SERVICES", "AI MODELS", "EVIDENCE & LEARNING", "RECENT RESULTS",
                      "GITHUB & RELEASES", "QUICK ACTIONS"):
            self.assertIn(label, joined)

    def test_every_tab_renders_at_full_and_compact_sizes(self):
        for w, h in ((160, 48), (120, 36), (80, 24), (60, 20)):
            for n, (_name, tabs) in enumerate(views.SECTIONS[1:], start=1):
                for t in range(len(tabs)):
                    st = dashboard.State()
                    dashboard.open_section(st, n, t)
                    self.render(w, h, st)  # raises curses.error on any out-of-bounds write

    def test_too_small_asks_for_resize(self):
        self.assertIn("needs 60x20", self.render(50, 15, dashboard.State()))


class Keys(unittest.TestCase):
    def setUp(self):
        self.st, self.c, self.data = dashboard.State(), FakeCollector(), fixture()

    def press(self, *keys):
        result = True
        for key in keys:
            result = dashboard.handle_key(ord(key) if isinstance(key, str) else key, self.st, self.data, self.c)
        return result

    def test_number_tab_escape_and_quit(self):
        self.press("3")
        self.assertEqual((self.st.level, self.st.section), ("section", 3))
        self.press(curses.KEY_RIGHT, curses.KEY_RIGHT)
        self.assertEqual(self.st.tab, 2)
        self.press(27)
        self.assertEqual(self.st.level, "home")
        self.assertFalse(self.press("q"))

    def test_home_grid_navigation_and_enter(self):
        self.press(curses.KEY_DOWN)
        self.assertEqual(self.st.home_focus, 3)
        self.press(curses.KEY_DOWN)
        self.assertEqual(self.st.home_focus, 6)
        self.press(curses.KEY_RIGHT, 10)
        self.assertEqual(self.st.section, views.SECTION_NAMES.index("MCP Services"))

    def test_search_from_home_opens_section(self):
        self.press("/", *"repair", 10)
        self.assertEqual(self.st.section, views.SECTION_NAMES.index("Repair Planner"))

    def test_search_filters_rows_and_escape_clears(self):
        self.press("1", "/", *"obsidian", 10)
        view = dashboard.current_view(self.data, self.st)
        self.assertEqual(len(dashboard.filtered_rows(view, self.st.search)), 1)
        self.press(27)
        self.assertEqual(self.st.search, "")
        self.assertEqual(self.st.level, "section")

    def test_export_requires_confirmation(self):
        self.press("9", 10)
        self.assertIsNotNone(self.st.confirm)
        self.press("n")
        self.assertEqual(self.c.actions, [])
        self.press(10, "y")
        self.assertEqual(self.c.actions, ["export"])

    def test_openai_test_requires_confirmation(self):
        self.press("3", curses.KEY_RIGHT, curses.KEY_RIGHT, curses.KEY_RIGHT, 10)
        self.assertIn("OpenAI", self.st.confirm["prompt"])
        self.press("y")
        self.assertEqual(self.c.actions, ["openai_test"])

    def test_refresh_and_help(self):
        self.press("r")
        self.assertEqual(self.c.refreshes, 1)
        self.press("h")
        self.assertEqual(views.SECTION_NAMES[self.st.section], "Help")

    def test_tab_switches_detail_focus(self):
        self.press("1", 9)
        self.assertEqual(self.st.focus, "detail")
        self.press(27)
        self.assertEqual(self.st.focus, "rows")


class ReviewRegressions(unittest.TestCase):
    """Defects found in review of the control-center PR."""

    def test_results_are_stored_as_they_finish(self):
        import time
        collector = sources.Collector({"slow": ("slow", lambda: time.sleep(2) or {}),
                                       "fast": ("fast", lambda: {"x": 1})}, github=False)
        collector.start()
        deadline = time.monotonic() + 1.0
        while "fast" not in collector.snapshot() and time.monotonic() < deadline:
            time.sleep(0.05)
        data = collector.snapshot()
        self.assertIn("fast", data)
        self.assertIn("slow", data["_pending"])

    def test_quitting_does_not_wait_for_running_sources(self):
        import subprocess
        import time
        script = ("import sys, time; sys.path.insert(0, %r); import dashboard_sources as s; "
                  "c = s.Collector({'slow': ('slow', lambda: time.sleep(6))}, github=False); c.start(); time.sleep(0.3)"
                  % str(DASH))
        started = time.monotonic()
        subprocess.run([sys.executable, "-c", script], timeout=20, check=True)
        self.assertLess(time.monotonic() - started, 3)

    def test_same_minute_snapshots_do_not_crash_history(self):
        data = {"snapshots": env({"stack-status": [{"file": "a.json", "status": "PASS", "mtime": "2026-10-17T10:00"},
                                                   {"file": "b.json", "status": "PASS", "mtime": "2026-10-17T10:00"}]}),
                "_pending": []}
        self.assertEqual(len(views.build_view(7, 2, data).rows), 2)

    def test_view_errors_render_instead_of_crashing(self):
        original = views._BUILDERS[("Automation", "Jobs")]
        views._BUILDERS[("Automation", "Jobs")] = lambda d, u: 1 / 0
        try:
            st = dashboard.State()
            dashboard.open_section(st, 7, 1)
            view = dashboard.current_view(fixture(), st)
        finally:
            views._BUILDERS[("Automation", "Jobs")] = original
        self.assertIn("ZeroDivisionError", views.text_of(view.lines[0]))

    def test_security_without_mcp_is_not_pass(self):
        data = fixture()
        data["mcp"] = failed("timeout")
        cards = {c[0]: c for c in views.health_cards(data)}
        self.assertNotEqual(cards["Security"][2], "PASS")

    def test_failed_openai_test_is_fail(self):
        data = fixture()
        data["openai_test"] = failed("TimeoutExpired")
        self.assertEqual(views.openai_state(data)[0], "FAIL")

    def test_action_note_reports_the_real_outcome(self):
        st, c = dashboard.State(), FakeCollector()
        st.confirm = {"kind": "export", "prompt": "?"}
        dashboard.run_confirmed(st, c, fixture())
        self.assertNotIn("written", st.note)
        dashboard.resolve_action_note(st, {"export": failed("PermissionError"), "_pending": []})
        self.assertIn("PermissionError", st.note)
        st.confirm = {"kind": "copy", "text": "ls", "prompt": "?"}
        dashboard.run_confirmed(st, c, fixture())
        dashboard.resolve_action_note(st, {"copy": env({"copied": "ls"}), "_pending": []})
        self.assertIn("Copied", st.note)

    def test_compact_home_arrows_follow_the_column(self):
        st = dashboard.State()
        st.home_compact = True
        dashboard.home_key(curses.KEY_DOWN, st)
        self.assertEqual(st.home_focus, 1)
        dashboard.home_key(curses.KEY_UP, st)
        self.assertEqual(st.home_focus, 0)

    def test_compact_home_shows_last_line_when_focused(self):
        st = dashboard.State()
        st.home_focus = 6
        screen = FakeScreen(60, 20)
        dashboard.draw(screen, dashboard.Theme(False), fixture(), st)
        self.assertIn("Quit", screen.text())

    def test_json_mode_reports_timed_out_sources(self):
        data = dashboard.finalize_for_json({"stack": env({}), "_pending": ["github"]})
        self.assertFalse(data["github"]["ok"])
        self.assertTrue(any(i["component"] == "source:github" for i in views.detect_issues(data)))


class EntryPoint(unittest.TestCase):
    def test_non_tty_exits_2_without_json(self):
        import subprocess
        result = subprocess.run([sys.executable, str(DASH / "mq_dashboard.py")], stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 2)
        self.assertIn("--json", result.stderr)


if __name__ == "__main__":
    unittest.main()
