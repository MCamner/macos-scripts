#!/usr/bin/env bash
# The one slot holding the last complete `mq.pulse.v1` document.
#
# It exists so that `mqlaunch pulse` followed by `mqlaunch next` costs one
# collection rather than two — about 4s of the second run being calls into other
# repos. What made that safe to build is v2.2.0 P0: the document now says when it
# was collected and under which flags, so a reader can decide whether to trust it
# from facts the document carries instead of a TTL Pulse would have had to
# invent.
#
# This file writes and locates. It decides nothing about whether a document is
# still good — that is the reader's, in mqlaunch/lib/next/select.sh, per
# docs/PULSE_CONTRACT.md:
#
#   Pulse publishes the age    the reader declares its tolerance
#
# Only a complete run is kept: full scope, no skip flags. One slot means the last
# writer wins, and a scoped run overwriting the full document would make the
# cache emptier the more Pulse is used — `pulse quality` would throw away a
# perfectly good full observation seconds before somebody asked for one.

# Where the document lives.
#
# A cache directory rather than the state directory install.sh uses: this file is
# regenerable, and losing it costs 4s rather than changing what anything does.
# That also means `rm -rf ~/.cache` clears it, which is what an operator clearing
# a cache expects to happen.
#
# One slot per checkout, keyed on BASE_DIR. A Pulse document is not purely a
# statement about the machine: the QUALITY section is this repo running its own
# gates and the GIT section is this repo worktree. Two checkouts sharing one slot
# would let `next` in one answer with an observation of the other, which reads as
# a machine-wide claim and is not one.
#
# `cksum` rather than a readable name: the key is a path, and a path flattened
# into a filename is either ambiguous or unbounded. It is POSIX, so it is on
# every machine this runs on, and a cache key does not need to resist anything.
pulse_cache_path() {
  if [[ -n "${MQ_PULSE_CACHE:-}" ]]; then
    printf '%s' "$MQ_PULSE_CACHE"
    return 0
  fi

  local key
  key="$(printf '%s' "${BASE_DIR:-unknown}" | cksum | cut -d" " -f1)"
  printf '%s/macos-scripts/pulse-%s.json' "${XDG_CACHE_HOME:-$HOME/.cache}" "$key"
}

# Whether this run is one worth keeping.
#
#   pulse_cache_keeps SCOPE NO_STACK NO_NETWORK
#
# Full scope, no skip flags. One slot means the last writer wins, and a scoped
# run overwriting the full document would make the cache emptier the more Pulse
# is used — `pulse quality` would throw away a perfectly good full observation
# seconds before somebody asked for one.
#
# The reader checks the same three facts again off the document itself, and that
# is not redundant: this decides what is worth storing, the reader decides what
# is safe to use. A document that reached the slot some other way still has to
# answer for itself.
pulse_cache_keeps() {
  [[ -z "$1" && "$2" == "0" && "$3" == "0" ]]
}

# Stores the document arriving on stdin as the last complete observation.
#
# Never fails the caller and never prints on stdout. A status command must not
# exit non-zero because a cache directory is read-only: the operator asked about
# the machine and got the answer, and the saving is an optimization for whoever
# asks next. It is the one place in Pulse where a failure is allowed to be quiet,
# because nothing downstream reads a result that was never written — a stale
# document is what would be dangerous, and not writing cannot produce one.
pulse_cache_store() {
  local path directory staged
  path="$(pulse_cache_path)"
  directory="${path%/*}"

  if ! mkdir -p "$directory" 2>/dev/null; then
    # Drained rather than left unread, so a caller writing into this on a pipe
    # is not handed EPIPE for a cache miss.
    cat >/dev/null
    return 0
  fi

  # Through a temporary in the same directory, then renamed. A reader opening the
  # file while it is being written must never see half a document — and half a
  # document parses as a read failure, which the reader would report as an
  # observation gap on a machine that is fine.
  staged="$path.$$.tmp"
  if cat > "$staged" 2>/dev/null && [[ -s "$staged" ]]; then
    mv -f "$staged" "$path" 2>/dev/null || rm -f "$staged" 2>/dev/null
  else
    rm -f "$staged" 2>/dev/null
  fi
  return 0
}
