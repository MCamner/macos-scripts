#!/usr/bin/env bash
# Holds the Git collector's two GitHub reads to being concurrent and independent.
#
# `gh pr list` and `gh run list` ask different questions and neither feeds the
# other — the branch the CI query needs comes from `git rev-parse`, not from the
# pull request list. Serially, a slow or hanging `gh pr list` delayed the CI read
# by its whole budget and then some, which is the roadmap box this file closes:
#
#   do not let one slow GitHub request block all other output
#
# What is asserted:
#
#   1. the two reads overlap — two 1s stubs cost about 1s, not 2s
#   2. a `gh pr list` that burns its whole budget does not stop the CI item from
#      being produced, and does not turn it into a gap
#   3. the items are reported in list order, never in the order they finish
#   4. each item keeps its own duration, not the pair's wall time
#
# 3 is the one that would rot quietly. Concurrency that reorders the screen is a
# different product: the operator reads the Git area top to bottom, and a row
# that moves because a network call was fast is a screen that cannot be
# described in a document.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULSE="$ROOT/tools/scripts/pulse.sh"

echo "SMOKE: pulse git collector concurrency"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

stub="$run_dir/stub"
mkdir -p "$stub/tools/scripts" "$stub/mqlaunch/lib" "$run_dir/bin"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub/mqlaunch/lib/pulse"
cp "$PULSE" "$stub/tools/scripts/pulse.sh"

git -C "$stub" init -q
git -C "$stub" config user.email t@example.com
git -C "$stub" config user.name Test
git -C "$stub" commit -q --allow-empty -m stub

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Writes a `gh` stub. PR_SLEEP and RUN_SLEEP are seconds; a negative sleep means
# "never answer", which the collector's own budget then has to cut.
make_gh() { # PR_SLEEP PR_BODY RUN_SLEEP RUN_BODY
  cat > "$run_dir/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$1" in
  pr)  sleep $1; printf '%s\n' '$2' ;;
  run) sleep $3; printf '%s\n' '$4' ;;
esac
EOF
  chmod +x "$run_dir/bin/gh"
}

PRS='[{"number":1,"isDraft":false,"mergeable":"MERGEABLE"}]'
RUNS='[{"status":"completed","conclusion":"success","workflowName":"Quality"}]'

# The exit code is not asserted here. `pulse git` reports on what it found, and
# these fixtures deliberately move between healthy and unavailable — the subject
# of this file is concurrency and ordering, which
# tests/pulse-machine-surface-smoke.sh already holds the exit codes for.
run_git() {
  PATH="$run_dir/bin:$PATH" MACOS_SCRIPTS_HOME="$stub" NO_COLOR=1 \
    bash "$stub/tools/scripts/pulse.sh" git --json \
    >"$run_dir/out.json" 2>"$run_dir/err" </dev/null || true
}

# Prints one field of the item with the given subject.
item_field() { # SUBJECT FIELD
  python3 - "$run_dir/out.json" "$1" "$2" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    doc = json.load(handle)
for section in doc.get("sections", {}).values():
    for item in section:
        if item.get("subject") == sys.argv[2]:
            print(item.get(sys.argv[3], ""))
            raise SystemExit(0)
print("")
PY
}

echo "[1/4] the two GitHub reads overlap rather than queue"
make_gh 1 "$PRS" 1 "$RUNS"
started="$(python3 -c 'import time; print(int(time.time()*1000))')"
run_git
ended="$(python3 -c 'import time; print(int(time.time()*1000))')"
elapsed=$((ended - started))
[[ "$(item_field "Pull requests" status)" == "PASS" ]] \
  || fail "the pull request read did not succeed: $(item_field "Pull requests" summary)"
[[ "$(item_field CI status)" == "PASS" ]] \
  || fail "the CI read did not succeed: $(item_field CI summary)"
# Two 1s calls. Serial is >= 2000 ms; concurrent is a little over 1000 ms. 1700
# is clear of both the noise and the wrong answer.
[[ "$elapsed" -lt 1700 ]] \
  || fail "the two reads took ${elapsed} ms — they are still serial"
echo "  ok: two 1s reads in ${elapsed} ms"

echo "[2/4] a pull request read that burns its budget does not take CI with it"
# The roadmap box, stated as a test. `gh pr list` never answers; the CI read is
# independent and must still produce a verdict rather than inheriting the gap.
cat > "$run_dir/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$1" in
  pr)  sleep 30 ;;
  run) printf '%s\n' '$RUNS' ;;
esac
EOF
chmod +x "$run_dir/bin/gh"
started="$(python3 -c 'import time; print(int(time.time()*1000))')"
PULSE_GH_TIMEOUT=2 run_git
ended="$(python3 -c 'import time; print(int(time.time()*1000))')"
elapsed=$((ended - started))
[[ "$(item_field "Pull requests" status)" == "UNAVAILABLE" ]] \
  || fail "a spent budget should be UNAVAILABLE, got $(item_field "Pull requests" status)"
[[ "$(item_field CI status)" == "PASS" ]] \
  || fail "a slow pull request read blocked CI: CI is $(item_field CI status)"
[[ "$elapsed" -lt 4000 ]] \
  || fail "the run took ${elapsed} ms — CI waited for the pull request budget"
echo "  ok: CI answered in ${elapsed} ms while the other read timed out"

echo "[3/4] the items are in list order, not in the order they finish"
# CI answers immediately, pull requests take a second. The screen must not
# reorder: Pull requests is listed first and stays first.
make_gh 1 "$PRS" 0 "$RUNS"
run_git
order="$(python3 - "$run_dir/out.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    doc = json.load(handle)
subjects = [item["subject"] for section in doc.get("sections", {}).values()
            for item in section
            if item["subject"] in ("Pull requests", "CI")]
print(",".join(subjects))
PY
)"
[[ "$order" == "Pull requests,CI" ]] \
  || fail "the Git area reordered by completion time: $order"
echo "  ok: Pull requests before CI even when CI answers first"

echo "[4/4] each read keeps its own duration"
# Not the pair's wall time. A duration that reported how long both took would
# make --verbose describe a cost nothing actually paid.
pr_ms="$(item_field "Pull requests" duration_ms)"
ci_ms="$(item_field CI duration_ms)"
[[ -n "$pr_ms" && -n "$ci_ms" ]] || fail "a duration is missing: pr=$pr_ms ci=$ci_ms"
[[ "$pr_ms" -ge 900 ]] || fail "the 1s pull request read reported ${pr_ms} ms"
[[ "$ci_ms" -lt 500 ]] \
  || fail "the immediate CI read reported ${ci_ms} ms — it inherited the pair's wall time"
echo "  ok: pr=${pr_ms} ms, ci=${ci_ms} ms, measured separately"

echo "OK: pulse git collector concurrency smoke test passed"
