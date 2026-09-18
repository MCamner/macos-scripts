#!/usr/bin/env bash
# Validate agent skills under skills/ and keep the SKILLS.md table in sync.
#
# Checks:
#   1. frontmatter name matches the skill directory
#   2. every SKILL.md has an "## Evals" section
#   3. skill cross-references ("use `<skill>`") point to existing skills
#   4. backticked file paths in SKILL.md files exist in the repo
#   5. the SKILLS.md table between the GENERATED markers matches frontmatter
#   6. vendored third-party skills are byte-identical to their checked-in
#      manifest, and carry their MQ evals outside the vendor tree
#   7. every skill is discoverable, identically, through both .agents/skills/
#      (Codex) and .claude/skills/ (Claude Code), as a link rather than a copy
#
# Usage:
#   ./scripts/check-skills.sh          # check only
#   ./scripts/check-skills.sh --fix    # regenerate the SKILLS.md table

set -euo pipefail
cd "$(dirname "$0")/.."

# Third-party skills vendored under their own licence. Their files are never
# edited here, so they are exempt from the one rule that would require editing
# them -- the ## Evals section inside SKILL.md -- and nothing else. Their evals
# live in skills/vendor-evals/<name>.md and their contents are pinned by
# skills/vendor-evals/<name>.sha256.
VENDORED=(pdf)

# Answers whether a skill is vendored third-party code.
is_vendored() {
  local name="$1" v
  for v in "${VENDORED[@]}"; do [[ "$v" == "$name" ]] && return 0; done
  return 1
}

BEGIN_MARK="<!-- BEGIN GENERATED SKILLS TABLE -->"
END_MARK="<!-- END GENERATED SKILLS TABLE -->"

FAIL=0
# Marks a failing check.
fail() { echo "FAIL: $1"; FAIL=1; }
# Coordinates ok behavior.
ok()   { echo "PASS: $1"; }

# Coordinates frontmatter field behavior.
frontmatter_field() {
  awk -v key="$2" -F': ' '$1 == key { sub("^" key ": ", ""); print; exit }' "$1"
}

# --- 1 + 2: frontmatter and Evals ------------------------------------------

for skill_md in skills/*/SKILL.md; do
  dir_name="$(basename "$(dirname "$skill_md")")"
  fm_name="$(frontmatter_field "$skill_md" name)"
  fm_desc="$(frontmatter_field "$skill_md" description)"

  if [[ "$fm_name" != "$dir_name" ]]; then
    fail "$skill_md frontmatter name '$fm_name' != directory '$dir_name'"
  fi
  if [[ -z "$fm_desc" ]]; then
    fail "$skill_md has no description in frontmatter"
  fi
  if [[ "$fm_name" == \"* || "$fm_desc" == \"* ]]; then
    fail "$skill_md frontmatter uses quoted values; keep them unquoted"
  fi
  if is_vendored "$dir_name"; then
    # Vendored: the evals belong outside the tree we must not edit.
    sidecar="skills/vendor-evals/$dir_name.md"
    if [[ ! -f "$sidecar" ]]; then
      fail "$dir_name is vendored but has no MQ evals at $sidecar"
    elif ! grep -q '^## Evals' "$sidecar"; then
      fail "$sidecar is missing an '## Evals' section"
    fi
  elif ! grep -q '^## Evals' "$skill_md"; then
    fail "$skill_md is missing an '## Evals' section"
  fi
done
[[ $FAIL -eq 0 ]] && ok "frontmatter and Evals sections"

# --- 3: skill cross-references ----------------------------------------------

REF_FAIL=0
while IFS=: read -r file ref; do
  ref="${ref#use \`}"; ref="${ref%\`}"
  if [[ ! -d "skills/$ref" ]]; then
    fail "$file references non-existent skill '$ref'"
    REF_FAIL=1
  fi
done < <(grep -HoE 'use `[a-z][a-z-]+`' skills/*/SKILL.md)
[[ $REF_FAIL -eq 0 ]] && ok "skill cross-references"

# --- 4: backticked paths exist ----------------------------------------------

PATH_FAIL=0
while IFS=: read -r file token; do
  token="${token#\`}"; token="${token%\`}"
  [[ "$token" == *"*"* || "$token" == *" "* ]] && continue   # globs, phrases
  [[ "$token" == -* || "$token" == /* || "$token" == .* ]] && continue
  [[ "$token" == \<* ]] && continue                          # placeholders
  # A path is valid if it exists (relative to repo root or the skill's own
  # directory, so a skill may reference its own assets), or if git ignores it
  # — a generated artifact (e.g. generated/tool-index.json) is absent from a
  # fresh checkout but is a legitimate reference. Only an absent, non-ignored
  # path is a dead reference.
  [[ "$token" =~ ^[A-Za-z0-9._-]+/$ ]] && continue           # bare top-level dir mention (bin/, tools/)
  skill_dir="$(dirname "$file")"
  if [[ ! -e "$token" && ! -e "$skill_dir/$token" ]] && ! git check-ignore -q "$token" 2>/dev/null; then
    fail "$file references missing path '$token'"
    PATH_FAIL=1
  fi
done < <(grep -HoE '`[A-Za-z][A-Za-z0-9._/-]*/[A-Za-z0-9._/*<>-]*`' skills/*/SKILL.md)
[[ $PATH_FAIL -eq 0 ]] && ok "referenced paths exist"

# --- 5: SKILLS.md table generated from frontmatter ---------------------------

# Generates table for docs or release automation.
generate_table() {
  echo "$BEGIN_MARK"
  echo "| Skill | Description |"
  echo "| ----- | ----------- |"
  for skill_md in skills/*/SKILL.md; do
    local name desc
    name="$(basename "$(dirname "$skill_md")")"
    desc="$(frontmatter_field "$skill_md" description)"
    echo "| [$name](skills/$name/SKILL.md) | $desc |"
  done
  echo "$END_MARK"
}

begin_line="$(grep -nF "$BEGIN_MARK" SKILLS.md | head -1 | cut -d: -f1 || true)"
end_line="$(grep -nF "$END_MARK" SKILLS.md | head -1 | cut -d: -f1 || true)"

if [[ -z "$begin_line" || -z "$end_line" || "$begin_line" -ge "$end_line" ]]; then
  fail "SKILLS.md is missing the GENERATED SKILLS TABLE markers"
elif [[ "${1:-}" == "--fix" ]]; then
  tmp="$(mktemp)"
  head -n "$((begin_line - 1))" SKILLS.md > "$tmp"
  generate_table >> "$tmp"
  tail -n "+$((end_line + 1))" SKILLS.md >> "$tmp"
  mv "$tmp" SKILLS.md
  ok "SKILLS.md table regenerated"
else
  current="$(sed -n "${begin_line},${end_line}p" SKILLS.md)"
  if [[ "$current" != "$(generate_table)" ]]; then
    fail "SKILLS.md table is out of sync with skill frontmatter; run ./scripts/check-skills.sh --fix"
  else
    ok "SKILLS.md table matches skill frontmatter"
  fi
fi

# --- 6: vendored skills match their manifest --------------------------------
#
# A vendored skill is exempt from one authoring rule, not from the gate. What
# replaces the rule is this: its files must be byte-identical to the manifest
# checked in beside its evals. Local edits to third-party material are the
# thing that makes a future re-sync unsafe, so they fail here.

VENDOR_FAIL=0
for name in "${VENDORED[@]}"; do
  manifest="skills/vendor-evals/$name.sha256"
  if [[ ! -f "$manifest" ]]; then
    fail "$name is vendored but has no integrity manifest at $manifest"
    VENDOR_FAIL=1
    continue
  fi
  if ! shasum -a 256 -c "$manifest" >/dev/null 2>&1; then
    fail "skills/$name does not match $manifest; re-sync deliberately or revert"
    shasum -a 256 -c "$manifest" 2>&1 | grep -v ': OK$' | sed 's/^/      /' || true
    VENDOR_FAIL=1
  fi
  # A file added to the vendor tree is drift the manifest cannot see, because
  # it only lists what it already knows about.
  tracked="$(git ls-files "skills/$name" | sort)"
  listed="$(awk '{print $2}' "$manifest" | sort)"
  if [[ "$tracked" != "$listed" ]]; then
    fail "skills/$name has files the manifest does not list, or vice versa"
    diff <(echo "$listed") <(echo "$tracked") | sed 's/^/      /' || true
    VENDOR_FAIL=1
  fi
done
[[ $VENDOR_FAIL -eq 0 ]] && ok "vendored skills match their manifest"

# --- 7: agent discovery parity ----------------------------------------------
#
# Both agents must see the same skill surface. Before this check, Codex saw two
# skills and Claude Code saw ten, and nothing said so. A skill present in only
# one tree, or copied into a tree rather than linked, is a silent split: the
# two agents then follow different instructions for the same task name.

AGENT_TREES=(.agents/skills .claude/skills)
DISCOVERY_FAIL=0

# 7a: every canonical skill reaches both agents.
for skill_md in skills/*/SKILL.md; do
  name="$(basename "$(dirname "$skill_md")")"
  for tree in "${AGENT_TREES[@]}"; do
    if [[ ! -f "$tree/$name/SKILL.md" ]]; then
      fail "$name is not discoverable at $tree/$name/SKILL.md"
      DISCOVERY_FAIL=1
    elif ! cmp -s "$skill_md" "$tree/$name/SKILL.md"; then
      fail "$tree/$name/SKILL.md differs from canonical $skill_md"
      DISCOVERY_FAIL=1
    fi
  done
done

# 7b: every entry is a link to skills/, not a copy and not a second root.
# Content comparison alone cannot see a copy: it is identical on the day it is
# made and drifts silently afterwards.
for tree in "${AGENT_TREES[@]}"; do
  [[ -d "$tree" ]] || continue
  for entry in "$tree"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    name="$(basename "$entry")"
    expected="../../skills/$name"
    if [[ ! -d "skills/$name" ]]; then
      fail "$tree/$name has no canonical definition at skills/$name/"
      DISCOVERY_FAIL=1
      continue
    fi
    if [[ ! -L "$entry" ]]; then
      fail "$entry is a copy; it must be a symlink to $expected"
      DISCOVERY_FAIL=1
      continue
    fi
    target="$(readlink "$entry")"
    if [[ "$target" != "$expected" ]]; then
      fail "$entry links to '$target'; expected '$expected'"
      DISCOVERY_FAIL=1
    fi
  done
done
[[ $DISCOVERY_FAIL -eq 0 ]] && ok "agent discovery parity"

if [[ $FAIL -ne 0 ]]; then
  echo "check-skills: FAILED"
  exit 1
fi
echo "check-skills: OK"
