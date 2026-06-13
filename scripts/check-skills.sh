#!/usr/bin/env bash
# Validate agent skills under skills/ and keep the SKILLS.md table in sync.
#
# Checks:
#   1. frontmatter name matches the skill directory
#   2. every SKILL.md has an "## Evals" section
#   3. skill cross-references ("use `<skill>`") point to existing skills
#   4. backticked file paths in SKILL.md files exist in the repo
#   5. the SKILLS.md table between the GENERATED markers matches frontmatter
#
# Usage:
#   ./scripts/check-skills.sh          # check only
#   ./scripts/check-skills.sh --fix    # regenerate the SKILLS.md table

set -euo pipefail
cd "$(dirname "$0")/.."

BEGIN_MARK="<!-- BEGIN GENERATED SKILLS TABLE -->"
END_MARK="<!-- END GENERATED SKILLS TABLE -->"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
ok()   { echo "PASS: $1"; }

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
  if ! grep -q '^## Evals' "$skill_md"; then
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

if [[ $FAIL -ne 0 ]]; then
  echo "check-skills: FAILED"
  exit 1
fi
echo "check-skills: OK"
