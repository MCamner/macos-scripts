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

echo "[1/9] doctor exists and compiles"
test -x "$DOCTOR"
bash -n "$DOCTOR"

# The tools doctor checks, and the utilities every world needs regardless.
CHECKED=(git gh uv python3 node eza fzf jq gitleaks pbcopy)
HELPERS=(bash sh cat sed awk tr wc head tail date hostname uname stty tput id)

echo "[2/9] build the worlds this contract is measured in"

# A world is a PATH: the helpers, plus a stub for each tool named. Nothing
# inherits the machine's real PATH, so "eza is missing" means the same thing on
# a laptop that has eza and on a runner that does not. Stubs are never executed
# — doctor only asks `command -v` — but they are executable so that stays true
# if it ever does more.
build_world() {
  # build_world <dir> <tool>...
  local dir="$1"; shift
  mkdir -p "$dir"
  local tool resolved
  for tool in "${HELPERS[@]}"; do
    resolved="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$resolved" ]] && ln -sf "$resolved" "$dir/$tool"
  done
  for tool in "$@"; do
    printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/$tool"
    chmod +x "$dir/$tool"
  done
}

# A checked tool that is also a helper could never be withheld, and the world
# would quietly test something other than what it says.
for tool in "${CHECKED[@]}" mqlaunch; do
  for helper in "${HELPERS[@]}"; do
    if [[ "$tool" == "$helper" ]]; then
      echo "FAIL: '$tool' is both a checked tool and a helper every world needs" >&2
      exit 1
    fi
  done
done

provisioned="$run_dir/bin-provisioned"
degraded="$run_dir/bin-degraded"
build_world "$provisioned" "${CHECKED[@]}" mqlaunch
build_world "$degraded"
echo "  ok: ${#CHECKED[@]} checked tools, present in one world and absent in the other"

# doctor is invoked through `env -i` so the caller's OPENAI_API_KEY and PATH
# cannot leak in — this suite must not pass or fail on whoever ran it. TERM is
# left unset on purpose: the tools must stay quiet without one, which
# tests/plain-output-contract-smoke.sh pins separately.
#
# `OPENAI_API_KEY` is one of the twelve checks, so the provisioned world sets it
# and the degraded world does not, the same split as the tools.
doctor_run() {
  # doctor_run <world-bin> <key|nokey> <out-prefix> [args...]
  local bin="$1" key="$2" prefix="$3"; shift 3
  local -a env_args=(HOME="$HOME" MACOS_SCRIPTS_HOME="$ROOT" PATH="$bin")
  [[ "$key" == "key" ]] && env_args+=(OPENAI_API_KEY="stub-key-for-this-test")
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

echo "[3/9] a provisioned machine reports success in both modes"
ok_human_exit="$(doctor_run "$provisioned" key ok-human)"
ok_json_exit="$(doctor_run "$provisioned" key ok-json --json)"

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

echo "[4/9] a stripped machine reports the warnings in both modes"
warn_human_exit="$(doctor_run "$degraded" nokey warn-human)"
warn_json_exit="$(doctor_run "$degraded" nokey warn-json --json)"

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

echo "[5/9] the two modes agree with each other"
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

echo "[6/9] the summary is derived, not printed"
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

echo "[7/9] every warning says what to do about it, in both modes"
# Naming what is missing is not the same as saying what to do. This is
# exhaustive rather than sampled: the degraded world warns on every check, so
# a check added without a hint fails here instead of shipping a blank line.
# Written to a file rather than read through `< <(...)`: a process substitution
# hides the exit status, so a python that bailed out would leave `hints` empty
# and every loop below would pass over nothing.
python3 - "$run_dir/warn-json.out" >"$run_dir/hints.txt" <<'PY'
import json
import sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
missing = [c for c in doc["checks"] if c["status"] != "ok"]
blank = [c["name"] for c in missing if not c.get("hint", "").strip()]
if blank:
    sys.exit("checks that warn without a hint: " + " ".join(blank))
for check in missing:
    print(check["hint"])
PY
mapfile -t hints <"$run_dir/hints.txt"
if (( ${#hints[@]} != warn_count )); then
  echo "FAIL: $warn_count checks warned but ${#hints[@]} hints came back" >&2
  exit 1
fi
printf '  ok: %s warnings, each carrying a hint\n' "${#hints[@]}"

# The screen has to carry the same advice as the document, or the operator and
# the script reading the same run are told different things.
human_plain="$(sed -e 's/\x1b\[[0-9;]*m//g' "$run_dir/warn-human.out")"
for hint in "${hints[@]}"; do
  case "$human_plain" in
    *"$hint"*) ;;
    *)
      echo "FAIL: --json advises '$hint' but the screen never says it" >&2
      exit 1
      ;;
  esac
done
printf '  ok: all %s hints appear on the screen too\n' "${#hints[@]}"

echo "[8/9] the next step is the one worth doing first"
# A next step that just names whichever check happened to run first would send a
# new operator to install `eza` while `mqlaunch` is not on PATH. Two worlds,
# differing by one tool, prove the order is a decision rather than an accident.
#
# `eza` is the least urgent thing doctor checks and `mqlaunch` the most, so
# their relative order is the one worth pinning: it cannot come out right by
# luck in both runs.
only_eza="$run_dir/bin-only-eza-missing"
eza_and_launcher="$run_dir/bin-eza-and-launcher-missing"
build_world "$only_eza" git gh uv python3 node fzf jq gitleaks pbcopy mqlaunch
build_world "$eza_and_launcher" git gh uv python3 node fzf jq gitleaks pbcopy
doctor_run "$only_eza" key next-eza >/dev/null
doctor_run "$eza_and_launcher" key next-launcher >/dev/null

# Coordinates next step behavior.
next_step() {
  # next_step <json-file>
  python3 - "$1" <<'PY'
import json
import sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
step = doc.get("next")
if not step:
    sys.exit("the document carries no 'next' step for a run that is not ok")
print(step)
PY
}
doctor_run "$only_eza" key next-eza-json --json >/dev/null
doctor_run "$eza_and_launcher" key next-launcher-json --json >/dev/null

step_eza="$(next_step "$run_dir/next-eza-json.out")"
step_launcher="$(next_step "$run_dir/next-launcher-json.out")"

case "$step_eza" in
  *eza*) ;;
  *)
    echo "FAIL: with only eza missing, the next step is '$step_eza'" >&2
    exit 1
    ;;
esac
case "$step_launcher" in
  *eza*)
    echo "FAIL: eza is advised before the launcher is even on PATH: '$step_launcher'" >&2
    exit 1
    ;;
esac
printf '  ok: eza alone -> "%s"; eza and the launcher -> "%s"\n' \
  "$step_eza" "$step_launcher"

# And the screen says it too, for the same reason the hints must.
for pair in "next-eza:$step_eza" "next-launcher:$step_launcher"; do
  prefix="${pair%%:*}"
  expected="${pair#*:}"
  screen="$(sed -e 's/\x1b\[[0-9;]*m//g' "$run_dir/$prefix.out")"
  case "$screen" in
    *"$expected"*) ;;
    *)
      echo "FAIL: --json advises '$expected' but the screen never says it" >&2
      exit 1
      ;;
  esac
done
echo "  ok: the screen names the same next step as the document"

echo "[9/9] a healthy machine is told what to run, not just that it is healthy"
# ROADMAP P2's exit gate asks that a new operator can find the right next
# command. A doctor that ends at "12 checks passed" answers half of it: the
# machine is fine, and now what?
#
# The recommendation is held to the surface the launcher advertises, not merely
# to being non-empty. Pointing a new operator at a command help does not list
# would send them somewhere they could not find their way back to.
python3 - "$run_dir/ok-json.out" "$ROOT/mqlaunch/lib/command-registry.json" <<'CHECK'
import json
import sys

doc = json.load(open(sys.argv[1], encoding="utf-8"))
registry = json.load(open(sys.argv[2], encoding="utf-8"))

step = doc.get("next")
if not step:
    sys.exit("a clean run carries no 'next' — the operator is told nothing to do")

words = step.split()
if words[0] != "mqlaunch" or len(words) < 2:
    sys.exit(f"the recommendation is not a mqlaunch command: {step!r}")

target = words[1]
entry = next((c for c in registry["commands"]
              if target == c["name"] or target in c.get("aliases", [])), None)
if entry is None:
    sys.exit(f"the recommendation {target!r} is not a registry command")
if not entry["operator_surface"]:
    sys.exit(f"the recommendation {target!r} is not advertised by help — "
             f"a new operator could not find it again")
print(f"  ok: a clean run recommends {step!r}, a public entrypoint")
CHECK

# And the screen says it, for the same reason the hints must.
recommended="$(python3 -c \
  "import json,sys; print(json.load(open(sys.argv[1]))['next'])" \
  "$run_dir/ok-json.out")"
screen_ok="$(sed -e 's/\x1b\[[0-9;]*m//g' "$run_dir/ok-human.out")"
case "$screen_ok" in
  *"$recommended"*) ;;
  *)
    echo "FAIL: --json recommends '$recommended' but the clean screen never says it" >&2
    exit 1
    ;;
esac

# The two verdicts must not collapse into one line. A doctor that recommends the
# same thing on a broken machine as on a working one has stopped reading it.
if [[ "$recommended" == "$step_launcher" ]]; then
  echo "FAIL: the same next step is given whether or not the machine works" >&2
  exit 1
fi
echo "  ok: the clean screen names it too, and it differs from the degraded advice"

bash -n "$0"

echo "OK: doctor's summary reflects its checks, both modes agree, and every run ends in something to do"
