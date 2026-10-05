"""`mqlaunch doctor --json` is a contract: mq-hal reads it.

mq-hal's brief, doctor summary and fix planner parse this output. Until now it
had no schema and no schema id, so a renamed key or a new status value would
reach them unannounced. The schema lives in schemas/mq.doctor-status.v1.json;
mq.doctor-fix-plan.v1 already names this format as its `source`.

The producer validates its own output here, on a provisioned machine and on a
degraded one, because the two take different paths through doctor.sh: a
degraded run is the one that carries `detail` and `hint` on its checks.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
DOCTOR = ROOT / "tools" / "scripts" / "doctor.sh"
SCHEMA_PATH = ROOT / "schemas" / "mq.doctor-status.v1.json"
CHECKED = ("git", "gh", "uv", "python3", "node", "eza", "fzf", "jq", "gitleaks", "pbcopy")
HELPERS = ("bash", "sh", "cat", "sed", "awk", "tr", "wc", "head", "tail", "date",
           "hostname", "uname", "stty", "tput", "id")


def _world(tmp_path: Path, provided: tuple[str, ...]) -> Path:
    """A PATH holding the shell helpers plus stubs for the tools in `provided`."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for tool in HELPERS:
        resolved = shutil.which(tool)
        if resolved:
            (bin_dir / tool).symlink_to(resolved)
    for tool in provided:
        stub = bin_dir / tool
        stub.write_text("#!/usr/bin/env bash\nexit 0\n")
        stub.chmod(0o755)
    return bin_dir


def _doctor_json(bin_dir: Path, with_key: bool) -> dict:
    env = {"HOME": os.environ.get("HOME", "/tmp"), "MACOS_SCRIPTS_HOME": str(ROOT), "PATH": str(bin_dir)}
    if with_key:
        env["OPENAI_API_KEY"] = "stub-key"
    result = subprocess.run(["bash", str(DOCTOR), "--json"], env=env, capture_output=True, text=True)
    return json.loads(result.stdout)


@pytest.fixture(scope="module")
def validator() -> Draft202012Validator:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


def test_schema_declares_its_contract_id():
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    assert schema["properties"]["schema"]["const"] == "mq.doctor-status.v1"


@pytest.mark.parametrize(
    "provided, with_key",
    [
        pytest.param(CHECKED + ("mqlaunch",), True, id="provisioned"),
        pytest.param(("git",), False, id="degraded"),
    ],
)
def test_doctor_json_conforms(tmp_path, validator, provided, with_key):
    doc = _doctor_json(_world(tmp_path, provided), with_key)
    errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.path))
    assert not errors, "\n".join(f"{list(e.path)}: {e.message}" for e in errors)
    assert doc["schema"] == "mq.doctor-status.v1"


def test_degraded_run_exercises_detail_and_hint(tmp_path, validator):
    """Guards the test itself: the optional fields must actually be validated."""
    doc = _doctor_json(_world(tmp_path, ("git",)), with_key=False)
    assert any("detail" in c for c in doc["checks"])
    assert any("hint" in c for c in doc["checks"])
    assert doc["status"] != "ok"
