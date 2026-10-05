#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVIEW="$ROOT/tools/scripts/ollama-document-review.py"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mq-ollama-review.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "SMOKE: Ollama document review"

echo "[1/6] direct mqlaunch route exposes tool help"
help_out="$(
  BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" \
    "$ROOT/bin/mqlaunch" ollama-review --help
)"
grep -q "Review scripts with local Ollama" <<<"$help_out"

echo "[2/6] file selection allows source and rejects secret-like names"
python3 - "$REVIEW" "$TMP_DIR" <<'PY'
import importlib.util
import pathlib
import sys

spec = importlib.util.spec_from_file_location("ollama_document_review", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

root = pathlib.Path(sys.argv[2])
(root / "safe.sh").write_text("#!/bin/sh\n", encoding="utf-8")
(root / "token.py").write_text("TOKEN = 'not-real'\n", encoding="utf-8")
(root / "notes.md").write_text("notes\n", encoding="utf-8")

selected = {path.name for path in module.iter_target_files([str(root)], 8)}
assert selected == {"safe.sh"}, selected
PY

echo "[3/6] endpoint fallbacks follow Ollama environment"
python3 - "$REVIEW" <<'PY'
import importlib.util
import os
import sys
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("ollama_document_review", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with patch.dict(os.environ, {}, clear=True):
    assert module.ollama_endpoint() == "http://127.0.0.1:11434/api/generate"
with patch.dict(os.environ, {"OLLAMA_HOST": "http://localhost:1234/"}, clear=True):
    assert module.ollama_endpoint() == "http://localhost:1234/api/generate"
with patch.dict(os.environ, {"OLLAMA_ENDPOINT": "http://example.test/generate"}, clear=True):
    assert module.ollama_endpoint() == "http://example.test/generate"
PY

echo "[4/6] response parsing is covered without network access"
python3 - "$REVIEW" <<'PY'
import importlib.util
import json
import sys
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("ollama_document_review", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Response:
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self):
        return json.dumps({"response": "  REVIEW_OK  "}).encode()

with patch.object(module.urllib.request, "urlopen", return_value=Response()) as urlopen:
    assert module.call_ollama("test-model", "http://example.test", "prompt") == "REVIEW_OK"
    request = urlopen.call_args.args[0]
    payload = json.loads(request.data)
    assert payload["model"] == "test-model"
    assert payload["stream"] is False
    assert payload["keep_alive"] == module.DEFAULT_KEEP_ALIVE
PY

echo "[5/6] keep_alive passes durations as strings and bare integers as seconds"
python3 - "$REVIEW" <<'PY'
import importlib.util
import json
import sys
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("ollama_document_review", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

assert module.parse_keep_alive("30m") == "30m"
assert module.parse_keep_alive("0") == 0
assert module.parse_keep_alive("-1") == -1

class Response:
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self):
        return json.dumps({"response": "OK"}).encode()

with patch.object(module.urllib.request, "urlopen", return_value=Response()) as urlopen:
    module.call_ollama("m", "http://example.test", "p", keep_alive=0)
    payload = json.loads(urlopen.call_args.args[0].data)
    assert payload["keep_alive"] == 0

assert module.parse_keep_alive("1h30m") == "1h30m"
assert module.parse_keep_alive("500ms") == "500ms"
for bad in ("abc", "10x", "m", "1.5", ""):
    try:
        module.parse_keep_alive(bad)
    except module.argparse.ArgumentTypeError:
        pass
    else:
        raise AssertionError(f"accepted invalid keep_alive {bad!r}")
PY

echo "[6/6] invalid --keep-alive fails with exit 2 before any network call"
set +e
bad_out="$(OLLAMA_HOST=http://127.0.0.1:9 python3 "$REVIEW" --keep-alive abc "$REVIEW" 2>&1)"
bad_rc=$?
set -e
[[ "$bad_rc" -eq 2 ]] || { echo "expected exit 2, got $bad_rc: $bad_out"; exit 1; }
grep -q "argument --keep-alive: 'abc' is not a duration" <<<"$bad_out"
if grep -q "Ollama" <<<"$bad_out"; then
  echo "invalid value reached Ollama: $bad_out"
  exit 1
fi

echo "OK: Ollama document review smoke test passed"
