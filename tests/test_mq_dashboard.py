"""MQ Dashboard read-only rendering smoke checks (no terminal required)."""
import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "terminal/dashboard/mq_dashboard.py"
spec = importlib.util.spec_from_file_location("mq_dashboard", SCRIPT)
dashboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dashboard)


class DashboardTests(unittest.TestCase):
    def test_navigation_modules(self):
        self.assertEqual(len(dashboard.SECTIONS), 10)
        self.assertEqual(len(dashboard.EVIDENCE_TABS), 6)
        self.assertEqual(len(dashboard.REPAIR_TABS), 6)

    def test_missing_data_never_claims_pass(self):
        data = {
            "stack": {}, "stack_error": "offline",
            "routing": {}, "routing_error": "offline",
            "services": [{"name": "se.mq.mcp", "port": 8765, "state": "UNAVAILABLE"}],
            "models": None, "github": "UNAVAILABLE", "repo_path_override": "not set",
            "collected_at": "test",
        }
        home = "\n".join(dashboard.lines_for("Home", 0, data))
        self.assertIn("UNAVAILABLE", home)
        self.assertNotIn("VERIFIED", home)
        routing = "\n".join(dashboard.lines_for("Evidence & Learning", 1, data))
        self.assertIn("UNAVAILABLE", routing)
        repair = "\n".join(dashboard.lines_for("Repair Planner", 3, data))
        self.assertIn("DISABLED", repair)

    def test_repo_values_from_input(self):
        data = {
            "stack": {"overall": "STALE", "repos": [{
                "name": "mq-agent", "version": "1.35", "commit": "abcdef12",
                "verification": {"status": "STALE"}
            }]},
            "routing": {"task_classes": {"docs-review": {
                "recommendation": "AWAITING_OPERATOR_APPROVAL",
                "eligible": True,
                "actual": {"observations": 26, "candidate_routes": 2,
                           "window_days": 44.9, "minimum_samples_per_route": 11},
                "routes": {"local-shadow": 15, "deterministic-local": 11},
                "gates": {"minimum_observations": True}
            }}},
            "services": [], "github": "UNAVAILABLE", "models": None,
            "collected_at": "test", "stack_error": "", "routing_error": "",
            "repo_path_override": "not set",
        }
        self.assertIn("STALE", "\n".join(dashboard.lines_for("Repositories", 0, data)))
        self.assertIn("26", "\n".join(dashboard.lines_for("Evidence & Learning", 1, data)))
        self.assertIn("15", "\n".join(dashboard.lines_for("Evidence & Learning", 1, data)))

    def test_failure_of_external_command_does_not_crash(self):
        ok, output = dashboard.run_readonly(["/definitely/missing/mq-command"])
        self.assertFalse(ok)
        self.assertTrue(output)


if __name__ == "__main__":
    unittest.main()
