#!/usr/bin/env zsh

# MQ ZSH Theme v3
# Variant-based zsh prompt theme
# Variants:
#   amber   (default)
#   green
#   minimal
#   ice

[[ -n "${MQ_ZSH_THEME_V3_LOADED:-}" ]] && return 0
export MQ_ZSH_THEME_V3_LOADED=1

autoload -Uz colors vcs_info add-zsh-hook
colors
setopt prompt_subst

: "${MQ_ZSH_VARIANT:=amber}"

# ------------------------------------------------------------
# Variant palette
# ------------------------------------------------------------
mq_theme_palette() {
  case "${MQ_ZSH_VARIANT}" in
    amber)
      typeset -g MQC_USER="%F{220}"
      typeset -g MQC_HOST="%F{179}"
      typeset -g MQC_PATH="%F{117}"
      typeset -g MQC_GIT="%F{141}"
      typeset -g MQC_OK="%F{46}"
      typeset -g MQC_ERR="%F{196}"
      typeset -g MQC_WARN="%F{214}"
      typeset -g MQC_TIME="%F{244}"
      typeset -g MQC_DIM="%F{242}"
      typeset -g MQC_ACCENT="%F{220}"
      ;;
    green)
      typeset -g MQC_USER="%F{82}"
      typeset -g MQC_HOST="%F{120}"
      typeset -g MQC_PATH="%F{159}"
      typeset -g MQC_GIT="%F{84}"
      typeset -g MQC_OK="%F{46}"
      typeset -g MQC_ERR="%F{196}"
      typeset -g MQC_WARN="%F{190}"
      typeset -g MQC_TIME="%F{244}"
      typeset -g MQC_DIM="%F{240}"
      typeset -g MQC_ACCENT="%F{82}"
      ;;
    minimal)
      typeset -g MQC_USER="%F{250}"
      typeset -g MQC_HOST="%F{245}"
      typeset -g MQC_PATH="%F{111}"
      typeset -g MQC_GIT="%F{146}"
      typeset -g MQC_OK="%F{76}"
      typeset -g MQC_ERR="%F{196}"
      typeset -g MQC_WARN="%F{180}"
      typeset -g MQC_TIME="%F{243}"
      typeset -g MQC_DIM="%F{240}"
      typeset -g MQC_ACCENT="%F{245}"
      ;;
    ice)
      typeset -g MQC_USER="%F{123}"
      typeset -g MQC_HOST="%F{81}"
      typeset -g MQC_PATH="%F{159}"
      typeset -g MQC_GIT="%F{147}"
      typeset -g MQC_OK="%F{50}"
      typeset -g MQC_ERR="%F{196}"
      typeset -g MQC_WARN="%F{229}"
      typeset -g MQC_TIME="%F{244}"
      typeset -g MQC_DIM="%F{240}"
      typeset -g MQC_ACCENT="%F{81}"
      ;;
    *)
      export MQ_ZSH_VARIANT="amber"
      mq_theme_palette
      return
      ;;
  esac
}

mq_theme_palette
typeset -g MQC_RESET="%f%k"

# ------------------------------------------------------------
# VCS / git info
# ------------------------------------------------------------
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' max-exports 2
zstyle ':vcs_info:git:*' formats '%b'
zstyle ':vcs_info:git:*' actionformats '%b|%a'

mq_git_dirty() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local dirty=""
  command git diff --no-ext-diff --quiet --exit-code 2>/dev/null || dirty="*"
  command git diff --no-ext-diff --cached --quiet --exit-code 2>/dev/null || dirty="+${dirty}"

  [[ -n "$dirty" ]] && print -r -- "$dirty"
}

mq_prompt_git() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  vcs_info
  local branch="${vcs_info_msg_0_:-}"
  local dirty
  dirty="$(mq_git_dirty)"

  [[ -z "$branch" ]] && return 0

  if [[ -n "$dirty" ]]; then
    print -n "${MQC_GIT}[${branch}]${MQC_RESET} ${MQC_ERR}${dirty}${MQC_RESET}"
  else
    print -n "${MQC_GIT}[${branch}]${MQC_RESET}"
  fi
}

# ------------------------------------------------------------
# Command duration
# ------------------------------------------------------------
typeset -g MQ_CMD_START=0
typeset -g MQ_CMD_DURATION=""
typeset -g MQ_LAST_STATUS=0

mq_preexec() {
  MQ_CMD_START=$EPOCHSECONDS
}

mq_format_duration() {
  local s="$1"

  if (( s < 1 )); then
    print -r -- ""
  elif (( s < 60 )); then
    print -r -- "${s}s"
  elif (( s < 3600 )); then
    print -r -- "$(( s / 60 ))m $(( s % 60 ))s"
  else
    print -r -- "$(( s / 3600 ))h $(( (s % 3600) / 60 ))m"
  fi
}

mq_set_title() {
  print -Pn "\e]0;%n@%m: %~\a"
}

mq_precmd() {
  local last_status="$?"
  local now="$EPOCHSECONDS"

  if (( MQ_CMD_START > 0 )); then
    local elapsed=$(( now - MQ_CMD_START ))
    MQ_CMD_DURATION="$(mq_format_duration "$elapsed")"
  else
    MQ_CMD_DURATION=""
  fi

  MQ_LAST_STATUS="$last_status"
  mq_set_title
}

add-zsh-hook preexec mq_preexec
add-zsh-hook precmd mq_precmd

# ------------------------------------------------------------
# Prompt helpers
# ------------------------------------------------------------
mq_short_path() {
  print -Pn "%2~"
}

mq_prompt_symbol() {
  local last_status="$1"

  if [[ "$last_status" -eq 0 ]]; then
    print -n "${MQC_OK}❯${MQC_RESET}"
  else
    print -n "${MQC_ERR}❯${MQC_RESET}"
  fi
}

mq_prompt_right() {
  local last_status="$1"
  local status_seg=""
  local git_seg=""
  local dur_seg=""
  local time_seg="${MQC_TIME}%*${MQC_RESET}"

  if [[ "$last_status" -ne 0 ]]; then
    status_seg="${MQC_ERR}exit:${last_status}${MQC_RESET} "
  fi

  git_seg="$(mq_prompt_git)"
  [[ -n "$git_seg" ]] && git_seg="${git_seg} "

  if [[ -n "${MQ_CMD_DURATION:-}" ]]; then
    dur_seg="${MQC_WARN}${MQ_CMD_DURATION}${MQC_RESET} "
  fi

  print -n "${status_seg}${git_seg}${dur_seg}${time_seg}"
}

# ------------------------------------------------------------
# Prompt layout
# ------------------------------------------------------------
PROMPT='
${MQC_ACCENT}┌─${MQC_RESET}${MQC_USER}%n${MQC_RESET}${MQC_DIM}@${MQC_RESET}${MQC_HOST}%m${MQC_RESET} ${MQC_DIM}in${MQC_RESET} ${MQC_PATH}$(mq_short_path)${MQC_RESET}
${MQC_ACCENT}└─${MQC_RESET}$(mq_prompt_symbol ${MQ_LAST_STATUS:-0}) '

RPROMPT='$(mq_prompt_right ${MQ_LAST_STATUS:-0})'

# ------------------------------------------------------------
# Quality-of-life defaults
# ------------------------------------------------------------
HISTSIZE=${HISTSIZE:-25000}
SAVEHIST=${SAVEHIST:-25000}

setopt AUTO_CD
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt PROMPT_SUBST

zmodload zsh/complist 2>/dev/null || true
