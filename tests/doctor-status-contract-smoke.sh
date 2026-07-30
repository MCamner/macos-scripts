#!/usr/bin/env bash
set -euo pipefail

# `mqlaunch doctor` is the first thing a new operator runs, and ROADMAP P2's exit
# gate is that they can understand the result. It could not: `run_normal_mode`
# ended in an unconditional `ok "MQ operational"` that never read the counters
# above it, so the screen reported success no matter what failed. The JSON was
# honest — `"status": "warn"` — which made the human surface, the one an operator
# actually reads, the one that lied.
#
# This holds the two properties that defect violated:
#
#   the summary is derived   the same binary must say different things about a
#                            provisioned machine and a stripped one
#   the modes agree          human and --json must reach the same verdict and
#                            the same exit status, or a script and a person
#                            reading the same run disagree
#
# Both worlds are built from PATH rather than from the machine the suite happens
# to run on. A CI runner has no `eza` and no `pbcopy`; a laptop has both. A test
# that asserted either state would pass in one place and fail in the other, and
# the point here is a contract, not an inventory.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="$ROOT/tools/scripts/doctor.sh"

echo "SMOKE: doctor status contract"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/6] doctor exists and compiles"
test -x "$DOCTOR"
bash -n "$DOCTOR"

# The tools doctor checks. Kept as one list so the two worlds cannot drift apart:
# the provisioned world stubs exactly what the degraded world withholds.
CHECKED=(git gh uv python3 node eza fzf jq gitleaks pbcopy)

echo "[2/6] build a provisioned world and a degraded one"

# Provisioned: real PATH plus a stub for anything missing, so the run is
# identical on a laptop and on a runner. Stubs are never executed — doctor only
# asks `command -v` — but they are made executable so that stays true if it ever
# does more.
provisioned="$run_dir/bin-provisioned"
mkdir -p "$provisioned"
for tool in "${CHECKED[@]}" mqlaunch; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$provisioned/$tool"
  chmod +x "$provisioned/$tool"
done

# Degraded: a PATH holding the utilities doctor and the shared UI need, and none
# of the tools it checks. Built by resolving each helper on the real PATH, so
# this does not hard-code /bin or /usr/bin.
degraded="$run_dir/bin-degraded"
mkdir -p "$degraded"
for tool in bash sh cat sed awk tr wc head tail date hostname uname stty tput id; do
  resolved="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$resolved" ]] && ln -sf "$resolved" "$degraded/$tool"
done
for tool in "${CHECKED[@]}" mqlaunch; do
  if [[ -e "$degraded/$tool" ]]; then
    echo "FAIL: '$tool' is both a checked tool and a helper the degraded world needs" >&2
    exit 1
  fi
done
echo "  ok: ${#CHECKED[@]} checked tools, present in one world and absent in the other"

# doctor is invoked through `env -i` so the caller's OPENAI_API_KEY and PATH
# cannot leak in — this suite must not pass or fail on whoever ran it. TERM is
# left unset on purpose: the tools must stay quiet without one, which
# tests/plain-output-contract-smoke.sh pins separately.
#
# `OPENAI_API_KEY` is one of the twelve checks, so the provisioned world sets it
# and the degraded world does not, the same split as the tools.
doctor_run() {
  # doctor_run <world-bin> <out-prefix> [args...]
  local bin="$1" prefix="$2"; shift 2
  local -a env_args=(HOME="$HOME" MACOS_SCRIPTS_HOME="$ROOT")
  if [[ "$bin" == "$provisioned" ]]; then
    env_args+=(PATH="$bin:$PATH" OPENAI_API_KEY="stub-key-for-this-test")
  else
    env_args+=(PATH="$bin")
  fi
  set +e
  env -i "${env_args[@]}" bash "$DOCTOR" "$@" \
    >"$run_dir/$prefix.out" 2>"$run_dir/$prefix.err"
  local status=$?
  set -e
  printf '%s\n' "$status"
}

# `section` prints the heading and then a rule of box-drawing characters, so the
# line worth reading is the first one after SUMMARY that carries actual text.
summary_line() {
  awk '/^SUMMARY$/ {found=1; next} found && NF && $0 !~ /^[─-]+$/ {print; exit}'
}

echo "[3/6] a provisioned machine reports success in both modes"
ok_human_exit="$(doctor_run "$provisioned" ok-human)"
ok_json_exit="$(doctor_run "$provisioned" ok-json --json)"

python3 - "$run_dir/ok-json.out" <<'PY'
import json
import sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
if doc["status"] != "ok" or doc["summary"]["warn"] or doc["summary"]["fail"]:
    sys.exit(f"provisioned world did not come back clean: {doc['summary']} "
             f"status={doc['status']}")
print(f"  ok: --json reports status ok, {doc['summary']['ok']} checks")
PY

if [[ "$ok_human_exit" != "0" || "$ok_json_exit" != "0" ]]; then
  echo "FAIL: a clean run must exit 0 (human=$ok_human_exit json=$ok_json_exit)" >&2
  exit 1
fi

echo "[4/6] a stripped machine reports the warnings in both modes"
warn_human_exit="$(doctor_run "$degraded" warn-human)"
warn_json_exit="$(doctor_run "$degraded" warn-json --json)"

warn_count="$(python3 - "$run_dir/warn-json.out" <<'PY'
import json
import sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
if doc["status"] == "ok":
    sys.exit("degraded world still reported status ok")
if doc["summary"]["warn"] < 1:
    sys.exit(f"degraded world reported no warnings: {doc['summary']}")
print(doc["summary"]["warn"])
PY
)"
printf '  ok: --json reports %s warnings\n' "$warn_count"

# The defect in one assertion. The old summary printed this line with nine
# checks warning, so a green tick and the word "operational" are exactly what
# must not survive a degraded run.
summary_human="$(sed -e 's/\x1b\[[0-9;]*m//g' "$run_dir/warn-human.out" \
  | summary_line)"
if [[ -z "$summary_human" ]]; then
  echo "FAIL: the human screen has no SUMMARY line to read" >&2
  sed -e 's/\x1b\[[0-9;]*m//g' "$run_dir/warn-human.out" >&2
  exit 1
fi
case "$summary_human" in
  *operational*)
    echo "FAIL: doctor still claims to be operational with $warn_count warnings:" >&2
    echo "  $summary_human" >&2
    exit 1
    ;;
esac
case "$summary_human" in
  *"$warn_count"*) ;;
  *)
    echo "FAIL: the summary does not name how many checks need attention:" >&2
    echo "  $summary_human (expected to mention $warn_count)" >&2
    exit 1
    ;;
esac
printf '  ok: summary reads "%s"\n' "$summary_human"

if [[ "$warn_human_exit" == "0" || "$warn_json_exit" == "0" ]]; then
  echo "FAIL: a degraded run must not exit 0 (human=$warn_human_exit json=$warn_json_exit)" >&2
  exit 1
fi

echo "[5/6] the two modes agree with each other"
# A person and a script reading the same machine must reach the same verdict.
if [[ "$ok_human_exit" != "$ok_json_exit" ]]; then
  echo "FAIL: clean run exits differently per mode (human=$ok_human_exit json=$ok_json_exit)" >&2
  exit 1
fi
if [[ "$warn_human_exit" != "$warn_json_exit" ]]; then
  echo "FAIL: degraded run exits differently per mode (human=$warn_human_exit json=$warn_json_exit)" >&2
  exit 1
fi
printf '  ok: exit %s clean, exit %s degraded, in both modes\n' \
  "$ok_human_exit" "$warn_human_exit"

echo "[6/6] the summary is derived, not printed"
# Without this the two checks above could both pass against a summary hard-coded
# the other way. The line has to change with the machine.
summary_ok="$(sed -e 's/\x1b\[[0-9;]*m//g' "$run_dir/ok-human.out" \
  | summary_line)"
if [[ "$summary_ok" == "$summary_human" ]]; then
  echo "FAIL: the same summary line is printed for both worlds — it is a constant" >&2
  echo "  $summary_ok" >&2
  exit 1
fi
printf '  ok: clean reads "%s"\n' "$summary_ok"

bash -n "$0"

echo "OK: doctor's summary reflects its checks, and both modes agree"
