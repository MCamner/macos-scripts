#!/usr/bin/env python3
"""Inspect known local MQ ecosystem repositories."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
DEFAULT_REPOS = [
    "mq-mcp",
    "mq-agent",
    "repo-signal",
    "macos-scripts",
    "mq-image-analyze",
    "mq-hal",
    "mq-ums",
    "mqobsidian",
    "atlas-one",
]

GITHUB_OWNER = "MCamner"


def repo_paths(selected: list[str] | None = None) -> list[Path]:
    names = selected or DEFAULT_REPOS
    paths = []
    for name in names:
        path = Path(name).expanduser()
        if not path.is_absolute():
            path = HOME / name
        if path.exists():
            paths.append(path)
    return paths


def git_status(repo: Path, only_modified: bool = False, only_untracked: bool = False) -> list[str]:
    if not (repo / ".git").exists():
        return ["not a git repo"]
    proc = subprocess.run(
        ["git", "-C", str(repo), "status", "--short"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        return [proc.stderr.strip() or "git status failed"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    if only_modified:
        lines = [line for line in lines if not line.startswith("??")]
    if only_untracked:
        lines = [line for line in lines if line.startswith("??")]
    return lines or []


def git_output(repo: Path, args: list[str]) -> tuple[int, str]:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return proc.returncode, (proc.stdout or proc.stderr).strip()


def command_output(args: list[str], cwd: Path | None = None) -> tuple[int, str]:
    proc = subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return proc.returncode, (proc.stdout or proc.stderr).strip()


def first_file_line(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()[0].strip()
    except (IndexError, OSError):
        return "-"


def file_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def version_for(repo: Path) -> str:
    return first_file_line(repo / "VERSION")


def readme_version_refs(repo: Path, limit: int = 3) -> list[str]:
    text = file_text(repo / "README.md")
    refs: list[str] = []
    for line in text.splitlines():
        if re.search(r"version|status|v\d+\.\d+\.\d+|\d+\.\d+\.\d+", line, re.I):
            refs.append(line.strip())
        if len(refs) >= limit:
            break
    return refs


def changelog_latest(repo: Path) -> str:
    for line in file_text(repo / "CHANGELOG.md").splitlines():
        stripped = line.strip()
        if "unreleased" in stripped.lower():
            continue
        if stripped.startswith("## [") or re.match(r"^##\s+v?\d+\.\d+\.\d+", stripped):
            return stripped
    return "-"


def roadmap_latest(repo: Path) -> str:
    for path in (repo / "ROADMAP.md", repo / "docs" / "ROADMAP.md"):
        for line in file_text(path).splitlines():
            stripped = line.strip()
            if re.search(r"Current|Latest|Next|v\d+\.\d+\.\d+", stripped):
                return stripped
    return "-"


def wiki_head(repo_name: str) -> tuple[str, str]:
    url = f"https://github.com/{GITHUB_OWNER}/{repo_name}.wiki.git"
    code, output = command_output(["git", "ls-remote", url, "HEAD"])
    if code != 0:
        return "missing", "-"
    sha = output.split()[0] if output else "-"
    return "yes", sha[:7]


def wiki_status(repo: Path) -> dict[str, str | list[str]]:
    version = version_for(repo)
    refs = readme_version_refs(repo)
    changelog = changelog_latest(repo)
    roadmap = roadmap_latest(repo)
    wiki, wiki_commit = wiki_head(repo.name)

    reasons: list[str] = []
    if version == "-":
        reasons.append("no VERSION")
    if not refs:
        reasons.append("no README version refs")
    elif version != "-" and not any(version in ref for ref in refs):
        reasons.append("README version mismatch")
    if version != "-" and version not in changelog:
        reasons.append("CHANGELOG version mismatch")
    if wiki != "yes":
        reasons.append("wiki missing")

    status = "OK" if not reasons else "STALE"
    return {
        "repo": repo.name,
        "version": version,
        "readme": " | ".join(refs) if refs else "-",
        "changelog": changelog,
        "roadmap": roadmap,
        "wiki": wiki,
        "wiki_commit": wiki_commit,
        "status": status,
        "reasons": reasons,
    }


def branch_summary(repo: Path) -> tuple[str, str]:
    code, output = git_output(repo, ["status", "--short", "--branch"])
    if code != 0:
        return "unknown", output or "git status failed"
    first = output.splitlines()[0] if output else "## unknown"
    first = first.removeprefix("## ").strip()
    if "..." not in first:
        return first or "unknown", "no-upstream"
    branch, tracking = first.split("...", 1)
    return branch.strip() or "unknown", tracking.strip() or "no-upstream"


def last_commit(repo: Path) -> str:
    code, output = git_output(repo, ["log", "-1", "--pretty=%h %cs %s"])
    if code != 0:
        return "no commits"
    return output


def origin_url(repo: Path) -> str:
    code, output = git_output(repo, ["remote", "get-url", "origin"])
    if code != 0:
        return "no-origin"
    return output


def cmd_status(args: argparse.Namespace) -> int:
    dirty = 0
    for repo in repo_paths(args.repo):
        if not (repo / ".git").exists():
            print(f"{repo.name}: not a git repo")
            dirty += 1
            continue
        branch, tracking = branch_summary(repo)
        changes = git_status(repo)
        modified = len([line for line in changes if not line.startswith("??")])
        untracked = len([line for line in changes if line.startswith("??")])
        state = "clean" if not changes else f"dirty ({modified} modified, {untracked} untracked)"
        if changes:
            dirty += 1

        print(f"{repo.name}: {state}")
        print(f"  branch: {branch}")
        print(f"  upstream: {tracking}")
        print(f"  origin: {origin_url(repo)}")
        print(f"  last: {last_commit(repo)}")
        if changes and args.limit > 0:
            print("  changes:")
            for line in changes[: args.limit]:
                print(f"    {line}")
            if len(changes) > args.limit:
                print(f"    ... {len(changes) - args.limit} more")
    return 1 if dirty and args.fail_on_dirty else 0


def cmd_list(args: argparse.Namespace) -> int:
    for repo in repo_paths(args.repo):
        marker = "git" if (repo / ".git").exists() else "dir"
        print(f"{repo.name}\t{marker}\t{repo}")
    return 0


def cmd_roadmaps(args: argparse.Namespace) -> int:
    for repo in repo_paths(args.repo):
        found = [p for p in (repo / "ROADMAP.md", repo / "docs" / "ROADMAP.md") if p.exists()]
        if found:
            for path in found:
                print(f"{repo.name}\t{path.relative_to(repo)}")
        else:
            print(f"{repo.name}\tMISSING")
    return 0


def cmd_skills(args: argparse.Namespace) -> int:
    for repo in repo_paths(args.repo):
        skills_dir = repo / "skills"
        count = len(list(skills_dir.glob("*/SKILL.md"))) if skills_dir.is_dir() else 0
        indexes = [p.name for p in (repo / "SKILLS.md", repo / "skills" / "platform-skills.md") if p.exists()]
        index_text = ",".join(indexes) if indexes else "no-index"
        print(f"{repo.name}\t{count} skill(s)\t{index_text}")
    return 0


def cmd_diff_summary(args: argparse.Namespace) -> int:
    dirty = 0
    for repo in repo_paths(args.repo):
        lines = git_status(
            repo,
            only_modified=args.modified,
            only_untracked=args.untracked,
        )
        if not lines:
            print(f"{repo.name}: clean")
            continue
        dirty += 1
        print(f"{repo.name}: {len(lines)} change(s)")
        for line in lines[: args.limit]:
            print(f"  {line}")
        if len(lines) > args.limit:
            print(f"  ... {len(lines) - args.limit} more")
    return 1 if dirty and args.fail_on_dirty else 0


def cmd_wiki_status(args: argparse.Namespace) -> int:
    stale = 0
    for repo in repo_paths(args.repo):
        data = wiki_status(repo)
        reasons = data["reasons"]
        if reasons:
            stale += 1
        print(f"{data['repo']}: {data['status']}")
        print(f"  VERSION:   {data['version']}")
        print(f"  README:    {data['readme']}")
        print(f"  CHANGELOG: {data['changelog']}")
        print(f"  ROADMAP:   {data['roadmap']}")
        print(f"  Wiki:      {data['wiki']} ({data['wiki_commit']})")
        if reasons:
            print("  Reasons:")
            for reason in reasons:
                print(f"    - {reason}")
    return 1 if stale and args.fail_on_stale else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", action="append", help="Repo name/path; may be repeated")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("list", help="List known repos")
    p.add_argument("--repo", action="append", help="Repo name/path; may be repeated")
    p.set_defaults(func=cmd_list)
    p = sub.add_parser("roadmaps", help="List roadmap files")
    p.add_argument("--repo", action="append", help="Repo name/path; may be repeated")
    p.set_defaults(func=cmd_roadmaps)
    p = sub.add_parser("skills", help="Summarize local skills")
    p.add_argument("--repo", action="append", help="Repo name/path; may be repeated")
    p.set_defaults(func=cmd_skills)
    p = sub.add_parser("diff-summary", help="Show git change summary per repo")
    p.add_argument("--repo", action="append", help="Repo name/path; may be repeated")
    p.add_argument("--limit", type=int, default=8)
    p.add_argument("--fail-on-dirty", action="store_true")
    p.add_argument("--modified", action="store_true", help="Show only modified/staged files")
    p.add_argument("--untracked", action="store_true", help="Show only untracked files")
    p.set_defaults(func=cmd_diff_summary)
    p = sub.add_parser("status", help="Show branch, upstream, origin, last commit and dirty state")
    p.add_argument("--repo", action="append", help="Repo name/path; may be repeated")
    p.add_argument("--limit", type=int, default=6, help="Changed-file preview limit per repo")
    p.add_argument("--fail-on-dirty", action="store_true")
    p.set_defaults(func=cmd_status)
    p = sub.add_parser("wiki-status", help="Show local docs and GitHub Wiki freshness signals")
    p.add_argument("--repo", action="append", help="Repo name/path; may be repeated")
    p.add_argument("--fail-on-stale", action="store_true")
    p.set_defaults(func=cmd_wiki_status)
    args = parser.parse_args(argv)
    if getattr(args, "modified", False) and getattr(args, "untracked", False):
        parser.error("--modified and --untracked are mutually exclusive")
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
