#!/usr/bin/env python3
"""Masks the volatile parts of a Performance screen, reading stdin.

Used by tests/performance-screens-golden-smoke.sh to compare the nine
`command_perf_*` screens against a committed golden. Only time-, machine-,
process- and checkout-dependent values are replaced. Labels, section headings,
box drawing, row counts, ordering and error text pass through unchanged, so a
change in any of those is a difference the golden reports.

This exists because docs/plans/step-12-v1-removal.md asked for a golden snapshot
before the performance data layer was migrated out of the frozen v1 tree, and
that fixture was never written — R1 in its risk table is unnoticed output drift,
and the mitigation for R1 was the step that got skipped. The snapshot was
reconstructed afterwards from a worktree of the commit before the migration; the
two sides matched on all nine screens, stdout, stderr and exit code.
"""
import os
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

# The checkout root, masked before anything else. CI checks out under
# /home/runner/work and a developer machine under /Users, and the location of
# the checkout is not part of what a screen renders. Passed in rather than
# guessed, so no rule has to enumerate every CI provider's layout.
REPO_ROOT = os.environ.get("MQ_NORMALIZE_ROOT", "")

RULES = [
    # Absolute paths. One marker for every root, so a worktree of an older
    # commit under /private/tmp compares equal to the live tree under /Users.
    # Where the checkout sits is not part of what a screen renders.
    (re.compile(r"/(?:private/)?(?:tmp|var)/[^\s\"'|]+"), "<PATH>"),
    (re.compile(r"/Users/[^\s\"'|]+"), "<PATH>"),
    # Load and uptime are NOT masked. `uptime` is stubbed with fixed output, so
    # both are deterministic, and masking them hid a defect for as long as they
    # were masked: `perf_load_1m` split `uptime` on ", " while macOS separates
    # the three figures with spaces, so the field rendered as one run of
    # concatenated decimals and `<LOADAVG>` covered it up. A golden that masks
    # the field a bug lives in cannot report the bug.
    # Dates and timestamps.
    (re.compile(r"\d{4}-\d{2}-\d{2}[_ ]\d{2}[-:]\d{2}([-:]\d{2})?"), "<TIMESTAMP>"),
    (re.compile(r"\d{4}-\d{2}-\d{2}"), "<DATE>"),
    (re.compile(r"\b\d{1,3}%"), "<PCT>"),
    # Network.
    (re.compile(r"\b\d{1,3}(?:\.\d{1,3}){3}\b"), "<IP>"),
    # Sizes. `du -sh` writes bare suffixes (656K, 10M, 228Gi), and the figures
    # differ between any two checkouts.
    (re.compile(r"\b\d+(?:\.\d+)?\s*(Gi?B|Mi?B|Ki?B|Ti?B)\b", re.I), "<SIZE>"),
    (re.compile(r"(?<![\w.])\d+(?:\.\d+)?[BKMGT]i?(?![\w.])"), "<SIZE>"),
    # Scores, counts, pids and any bare number left over.
    (re.compile(r"\b(\d+)/100\b"), "<SCORE>/100"),
    (re.compile(r"\b\d+(?:\.\d+)+\b"), "<NUM>"),
    (re.compile(r"\b\d+\b"), "<N>"),
]

# Lines that pass through untouched. `uptime` is stubbed, so everything on them
# is deterministic, and every one of them carries a load average — the field a
# defect lived in while the masking covered it up. The malformed value even
# matched the IP rule, four dot-separated groups being exactly what
# "1.501.251.10" looks like, so the fixture read `Load (1m): <IP>`.
PASSTHROUGH = (
    re.compile(r".*Load \(1m\):"),
    re.compile(r".*load averages?:"),
)

# A row of `ps` output. Which processes are in a top-N list changes between two
# runs seconds apart, so the rows themselves are process-dependent data and not
# just the numbers in them. Each collapses to one marker, so the *number* of
# rows and everything around them still compares.
PROCESS_ROW = re.compile(r"^\s*(?:<N>|<NUM>|<PCT>)\s+\S.*$")

# `du -sh` right-aligns its size column, so the leading padding depends on the
# widest entry in that particular tree.
SIZE_ROW = re.compile(r"\s*<SIZE>\s+<PATH>")


def normalize(line: str) -> str:
    line = ANSI.sub("", line.rstrip("\n"))
    if REPO_ROOT:
        line = line.replace(REPO_ROOT, "<REPO>")
    if any(p.match(line) for p in PASSTHROUGH):
        return re.sub(r"\s+$", "", line)
    for pattern, replacement in RULES:
        line = pattern.sub(replacement, line)
    line = re.sub(r"\s+$", "", line)
    if PROCESS_ROW.match(line):
        return "<PROCESS_ROW>"
    if SIZE_ROW.fullmatch(line):
        return "<SIZE_ROW>"
    return line


def main() -> None:
    for raw in sys.stdin:
        print(normalize(raw))


if __name__ == "__main__":
    main()
