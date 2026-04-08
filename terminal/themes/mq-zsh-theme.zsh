#!/usr/bin/env zsh

# MQ ZSH Theme
# Real shell prompt theme for zsh
# Separate from mq-ui.sh

[[ -n "${MQ_ZSH_THEME_LOADED:-}" ]] && return 0
export MQ_ZSH_THEME_LOADED=1

autoload -Uz colors vcs_info add-zsh-hook
colors
setopt prompt_subst

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
    print -n "%F{141}[${branch}]%f %F{196}${dirty}%f"
  else
    print -n "%F{141}[${branch}]%f"
  fi
}

# ------------------------------------------------------------
# Prompt helpers
# ------------------------------------------------------------
mq_prompt_symbol() {
  local last_status="$1"

  if [[ "$last_status" -eq 0 ]]; then
    print -n "%F{46}❯%f"
  else
    print -n "%F{196}❯%f"
  fi
}

mq_prompt_right() {
  local last_status="$1"
  local status_seg=""
  local git_seg=""
  local time_seg="%F{244}%*%f"

  if [[ "$last_status" -ne 0 ]]; then
    status_seg="%F{196}exit:${last_status}%f "
  fi

  git_seg="$(mq_prompt_git)"
  [[ -n "$git_seg" ]] && git_seg="${git_seg} "

  print -n "${status_seg}${git_seg}${time_seg}"
}

mq_set_title() {
  print -Pn "\e]0;%n@%m: %~\a"
}

mq_precmd() {
  mq_set_title
}

add-zsh-hook precmd mq_precmd

# ------------------------------------------------------------
# Prompt
# ------------------------------------------------------------
PROMPT='
%F{39}%n@%m%f %F{111}%~%f
$(mq_prompt_symbol $?) '

RPROMPT='$(mq_prompt_right $?)'

# ------------------------------------------------------------
# Optional shell quality-of-life
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
