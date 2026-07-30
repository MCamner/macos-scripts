#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVIEW="$ROOT/tools/scripts/ollama-document-review.py"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mq-ollama-review.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "SMOKE: Ollama document review"

echo "[1/4] direct mqlaunch route exposes tool help"
help_out="$(MACOS_SCRIPTS_HOME="$ROOT" "$ROOT/bin/mqlaunch" ollama-review --help)"
grep -q "Review scripts with local Ollama" <<<"$help_out"

echo "[2/4] file selection allows source and rejects secret-like names"
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

echo "[3/4] endpoint fallbacks follow Ollama environment"
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

echo "[4/4] response parsing is covered without network access"
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
PY

echo "OK: Ollama document review smoke test passed"
