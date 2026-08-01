#!/usr/bin/env bash
# Guards install.sh — what the installer puts on PATH, and whether it stays the
# same file as the repo.
#
# Two defects motivated this. The installer symlinked
# terminal/launchers/mqlaunch.sh directly, past bin/mqlaunch, which is the only
# file that routes `mqlaunch repl` — so a fresh install produced a working
# mqlaunch whose repl answered "Unknown command: repl". The machine this was
# found on escaped it because its symlink had been made by hand to the right
# target years after the installer stopped agreeing.
#
# And `gitlaunch` was on PATH as a hand-made copy rather than a link: 453 lines
# dated 25 June against the repo's 1122, so every change since — the eight-choice
# grouping, the 92-column convergence, the protected-push guard — reached
# `mqlaunch git` and not the command the hand types. A copy cannot be kept
# current by committing to the repo, which is the whole argument for linking.
#
# So the assertions are: every entrypoint in bin/ is installed, each link
# resolves *into* bin/ rather than past it, and the installed mqlaunch answers
# the one subcommand that only bin/mqlaunch knows.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: install contract"

echo "[1/6] the installer and its entrypoints exist"
test -x "$ROOT/install.sh"
test -d "$ROOT/bin"
entrypoints=()
while IFS= read -r path; do
  entrypoints+=("$(basename "$path")")
done < <(git -C "$ROOT" ls-files 'bin/*' | while IFS= read -r f; do
  [[ -x "$ROOT/$f" ]] && printf '%s\n' "$f"
done)
(( ${#entrypoints[@]} > 0 )) || {
  echo "FAIL: bin/ holds no executable entrypoint" >&2
  exit 1
}

echo "[2/6] a dry run changes nothing"
tmp_bin="$(mktemp -d)"
tmp_state="$(mktemp -d)"
cleanup() { rm -rf "$tmp_bin" "$tmp_state"; }
trap cleanup EXIT

HOME="$tmp_state" ZDOTDIR="$tmp_state" TERM="${TERM:-dumb}" \
  "$ROOT/install.sh" --dry-run --yes --bin-dir "$tmp_bin" >/dev/null
if [[ -n "$(ls -A "$tmp_bin")" ]]; then
  echo "FAIL: --dry-run created something in $tmp_bin" >&2
  exit 1
fi

echo "[3/6] every entrypoint in bin/ is installed"
# The installer knew about one name. Adding a second file to bin/ without
# teaching it is how a command ends up hand-copied onto PATH and frozen there.
HOME="$tmp_state" ZDOTDIR="$tmp_state" TERM="${TERM:-dumb}" \
  "$ROOT/install.sh" --yes --bin-dir "$tmp_bin" >/dev/null
missing=()
for name in "${entrypoints[@]}"; do
  [[ -e "$tmp_bin/$name" ]] || missing+=("$name")
done
if (( ${#missing[@]} > 0 )); then
  echo "FAIL: bin/ entrypoint(s) the installer does not install: ${missing[*]}" >&2
  exit 1
fi
echo "  ok: ${#entrypoints[@]} entrypoint(s) installed"

echo "[4/6] each one is a link into bin/, not a copy and not a link past it"
for name in "${entrypoints[@]}"; do
  link="$tmp_bin/$name"
  if [[ ! -L "$link" ]]; then
    echo "FAIL: $name was installed as a copy, which cannot follow the repo" >&2
    exit 1
  fi
  target="$(readlink "$link")"
  if [[ "$target" != "$ROOT/bin/$name" ]]; then
    echo "FAIL: $name links to $target, not to $ROOT/bin/$name" >&2
    exit 1
  fi
done
echo "  ok: every link resolves into bin/"

echo "[5/6] the installed mqlaunch answers what only bin/mqlaunch routes"
# `repl` is handled in bin/mqlaunch and nowhere else — the launcher it execs
# reports it as unknown. That makes it the behavioural difference between the
# two link targets, and a stronger assertion than comparing paths. Driven with
# no stdin, which the REPL exits on rather than blocking.
repl_out="$(timeout 30 "$tmp_bin/mqlaunch" repl </dev/null 2>&1 || true)"
if printf '%s' "$repl_out" | grep -q 'Unknown command: repl'; then
  echo "FAIL: the installed mqlaunch does not route repl; the link goes past bin/mqlaunch" >&2
  exit 1
fi
echo "  ok: repl is routed"

echo "[6/6] gitlaunch dispatches rather than running the menu itself"
# It is a wrapper, not a second entrypoint: the repo has one dispatcher, and a
# gitlaunch that exec'd terminal/launchers/gitlaunch.sh directly would be a
# second way into a command `mqlaunch git` already routes — the class the
# discovery inventory gates at zero. Proven with a stub in BASE_DIR rather than
# by grepping, so what is asserted is the argv it hands over.
stub_root="$(mktemp -d)"
mkdir -p "$stub_root/bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*"\n' >"$stub_root/bin/mqlaunch"
chmod +x "$stub_root/bin/mqlaunch"
handed_over="$(BASE_DIR="$stub_root" "$ROOT/bin/gitlaunch" ~/some-repo 2>&1)"
rm -rf "$stub_root"
if [[ "$handed_over" != "git $HOME/some-repo" ]]; then
  echo "FAIL: gitlaunch handed over '$handed_over', expected 'git \$HOME/some-repo'" >&2
  exit 1
fi
echo "  ok: gitlaunch runs 'mqlaunch git' with its arguments"

echo "OK: install contract smoke test passed"
