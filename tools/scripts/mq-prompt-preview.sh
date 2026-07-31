#!/usr/bin/env zsh
# Preview: terminal prompt header matching mqlaunch Command Surface v3 style

C_RESET=$'\e[0m'
C_BORDER=$'\e[38;5;136m'
C_GOLD=$'\e[1;38;5;178m'
C_AMBER=$'\e[38;5;178m'
C_DIM=$'\e[38;5;244m'
C_WHITE=$'\e[97m\e[38;2;255;255;255m'
C_FIG1=$'\e[38;5;76m'    # green — C_OK in mqlaunch
C_FIG2=$'\e[38;5;221m'   # amber — ALT_FIGURE_COLOR in mqlaunch

# ── data ──────────────────────────────────────────────────────
NOW_TIME=$(date "+%H:%M:%S")
NOW_DATE=$(date "+%a %d %b %Y")
ZSH_VER=$(zsh --version 2>/dev/null | awk '{print $2}')
ZSH_ARCH=$(zsh --version 2>/dev/null | sed 's/.*(\(.*\))/\1/')
# ── figures (same blocks as Command Surface v3) ───────────────
FIG1_1="▄▄████▄▄"
FIG1_2="████████"
FIG1_3="██▄██▄██"
FIG1_4=" ▄█▀▀█▄ "

FIG2_1=" ▄▄██▄▄ "
FIG2_2="█▀████▀█"
FIG2_3="██▀██▀██"
FIG2_4=" ▀▄██▄▀ "

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
  "$C_WHITE" "    zsh $ZSH_VER" "$C_RESET"

printf "  %b%s%b  %b%s%b  %b%s%b\n" \
  "$C_FIG1" "$FIG1_4" "$C_RESET" \
  "$C_FIG2" "$FIG2_4" "$C_RESET" \
  "$C_WHITE" "    $ZSH_ARCH" "$C_RESET"

echo
