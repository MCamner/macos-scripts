#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/security" <<'STUB'
#!/usr/bin/env bash
printf 'fixture-key-not-real'
STUB
chmod +x "$tmp/security"
set +e
out="$(env -u OPENAI_API_KEY MACOS_SCRIPTS_HOME="$ROOT" MQ_SECURITY_BIN="$tmp/security" bash "$ROOT/tools/scripts/doctor.sh" --json)"
set -e
python3 - "$out" <<'PY'
import json,sys
d=json.loads(sys.argv[1]); rows=d['checks']; row=next(x for x in rows if x['name']=='OPENAI_API_KEY'); assert row['status']=='ok',row
assert 'fixture-key-not-real' not in sys.argv[1]
PY
echo 'OK: doctor accepts local Keychain credential without exposing it'
