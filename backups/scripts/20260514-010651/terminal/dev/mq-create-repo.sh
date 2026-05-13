#!/usr/bin/env bash
set -u

DEFAULT_ROOT="/Users/mansys"
DEFAULT_OWNER="MCamner"

hr() {
  printf '%s\n' "────────────────────────────────────────────────────────────"
}

pause() {
  printf '\nPress Enter to continue...'
  read -r _
}

fail() {
  echo "✖ $1"
  exit 1
}

safe_repo_name() {
  basename "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9._-'
}

echo
echo "CREATE REPO"
hr
echo "Create or connect a local folder to a GitHub repository."
echo

printf "Local folder under %s: " "$DEFAULT_ROOT/"
read -r INPUT_PATH

[ -n "$INPUT_PATH" ] || fail "No folder path provided."

case "$INPUT_PATH" in
  "$DEFAULT_ROOT"/*)
    LOCAL_PATH="$INPUT_PATH"
    ;;
  /*)
    fail "Path must be under $DEFAULT_ROOT"
    ;;
  *)
    LOCAL_PATH="$DEFAULT_ROOT/$INPUT_PATH"
    ;;
esac

LOCAL_PATH="${LOCAL_PATH%/}"

[ -d "$LOCAL_PATH" ] || fail "Folder does not exist: $LOCAL_PATH"

REPO_NAME="$(safe_repo_name "$LOCAL_PATH")"
[ -n "$REPO_NAME" ] || fail "Could not derive repo name from folder."

echo
printf "GitHub owner [%s]: " "$DEFAULT_OWNER"
read -r OWNER
OWNER="${OWNER:-$DEFAULT_OWNER}"

printf "GitHub repo name [%s]: " "$REPO_NAME"
read -r INPUT_REPO_NAME
REPO_NAME="${INPUT_REPO_NAME:-$REPO_NAME}"

printf "Visibility public/private [public]: "
read -r VISIBILITY
VISIBILITY="${VISIBILITY:-public}"

case "$VISIBILITY" in
  public|private)
    ;;
  *)
    fail "Visibility must be public or private."
    ;;
esac

FULL_REPO="$OWNER/$REPO_NAME"

echo
echo "SUMMARY"
hr
echo "Local path:    $LOCAL_PATH"
echo "GitHub repo:   $FULL_REPO"
echo "Visibility:    $VISIBILITY"
echo

printf "Continue and create/connect repo? [y/N]: "
read -r CONFIRM

case "$CONFIRM" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Cancelled."
    exit 0
    ;;
esac

command -v git >/dev/null 2>&1 || fail "git not found."
command -v gh >/dev/null 2>&1 || fail "GitHub CLI 'gh' not found."

if ! gh auth status >/dev/null 2>&1; then
  fail "gh is not authenticated. Run: gh auth login"
fi

cd "$LOCAL_PATH" || fail "Could not cd to $LOCAL_PATH"

echo
echo "PREPARE FILES"
hr

if [ ! -f ".gitignore" ]; then
  cat > .gitignore <<'GITIGNORE'
# macOS
.DS_Store

# Python
__pycache__/
*.pyc
.venv/
venv/
.env

# Node
node_modules/
npm-debug.log*

# Secrets / local config
*.key
*.pem
*.p12
*.pfx
.env.local
secrets.*
settings.local.json
.claude/settings.local.json

# Logs
*.log
logs/
GITIGNORE
  echo "✔ Created .gitignore"
else
  echo "✔ .gitignore exists"
fi

if [ ! -f "README.md" ]; then
  cat > README.md <<EOF_README
# $REPO_NAME

Local project repository.

## Status

Early prototype.

## Notes

Do not commit API keys, local secrets, or private environment files.
EOF_README
  echo "✔ Created README.md"
else
  echo "✔ README.md exists"
fi

echo
echo "GIT SETUP"
hr

if [ ! -d ".git" ]; then
  git init
  git branch -M main
  echo "✔ Git initialized"
else
  echo "✔ Git already initialized"
fi

git add .

if git diff --cached --quiet; then
  echo "✔ No staged changes to commit"
else
  git commit -m "Initial commit"
  echo "✔ Commit created"
fi

echo
echo "GITHUB SETUP"
hr

REMOTE_URL="git@github.com:${FULL_REPO}.git"

if gh repo view "$FULL_REPO" >/dev/null 2>&1; then
  echo "✔ GitHub repo already exists: $FULL_REPO"

  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi

  git push -u origin main
else
  if [ "$VISIBILITY" = "private" ]; then
    gh repo create "$FULL_REPO" \
      --private \
      --source=. \
      --remote=origin \
      --push
  else
    gh repo create "$FULL_REPO" \
      --public \
      --source=. \
      --remote=origin \
      --push
  fi
fi

echo
echo "DONE"
hr
echo "✔ Repo connected: $FULL_REPO"
echo "✔ Local path: $LOCAL_PATH"
echo

if command -v repo-signal >/dev/null 2>&1; then
  echo "REPO SIGNAL"
  hr
  repo-signal publish-checklist .
fi
