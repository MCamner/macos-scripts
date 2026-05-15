#!/usr/bin/env zsh
# Preview: terminal prompt header matching mqlaunch Command Surface v3 style

C_RESET=$'\e[0m'
C_BORDER=$'\e[38;5;136m'
C_GOLD=$'\e[1;38;5;178m'
C_AMBER=$'\e[38;5;178m'
C_DIM=$'\e[38;5;244m'
C_FIG1=$'\e[38;5;76m'    # green — C_OK in mqlaunch
C_FIG2=$'\e[38;5;221m'   # amber — ALT_FIGURE_COLOR in mqlaunch

repeat_char() { printf '%*s' "$1" '' | tr ' ' "$2"; }

# ── data ──────────────────────────────────────────────────────
NOW_TIME=$(date "+%H:%M:%S")
NOW_DATE=$(date "+%a %d %b %Y")
ZSH_VER=$(zsh --version 2>/dev/null | awk '{print $2}')
ZSH_ARCH=$(zsh --version 2>/dev/null | sed 's/.*(\(.*\))/\1/')
COLS=$(tput cols 2>/dev/null || echo 72)

# ── figures (same blocks as Command Surface v3) ───────────────
FIG1_1="▄▄████▄▄"
FIG1_2="████████"
FIG1_3="██▄██▄██"
FIG1_4=" ▄█▀▀█▄ "

FIG2_1=" ▄▄██▄▄ "
FIG2_2="█▀████▀█"
FIG2_3="██▀██▀██"
FIG2_4=" ▀▄██▄▀ "

# ── separator under everything ────────────────────────────────
SEP_WIDTH=$(( COLS - 2 ))
(( SEP_WIDTH < 20 )) && SEP_WIDTH=20

# ── render ────────────────────────────────────────────────────
echo

printf "  %b%s%b  %b%s%b  %b%s%b\n" \
  "$C_FIG1" "$FIG1_1" "$C_RESET" \
  "$C_FIG2" "$FIG2_1" "$C_RESET" \
  "$C_GOLD" "⚡  $NOW_DATE" "$C_RESET"

printf "  %b%s%b  %b%s%b  %b%s%b\n" \
  "$C_FIG1" "$FIG1_2" "$C_RESET" \
  "$C_FIG2" "$FIG2_2" "$C_RESET" \
  "$C_AMBER" "    $NOW_TIME" "$C_RESET"

printf "  %b%s%b  %b%s%b  %b%s%b\n" \
  "$C_FIG1" "$FIG1_3" "$C_RESET" \
  "$C_FIG2" "$FIG2_3" "$C_RESET" \
  "$C_DIM" "    zsh $ZSH_VER" "$C_RESET"

printf "  %b%s%b  %b%s%b  %b%s%b\n" \
  "$C_FIG1" "$FIG1_4" "$C_RESET" \
  "$C_FIG2" "$FIG2_4" "$C_RESET" \
  "$C_DIM" "    $ZSH_ARCH" "$C_RESET"

printf "  %b%s%b\n" "$C_BORDER" "$(repeat_char "$SEP_WIDTH" '─')" "$C_RESET"
echo
