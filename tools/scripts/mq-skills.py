#!/usr/bin/env python3
"""Audit, validate and scaffold local MQ ecosystem skills."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
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
    "atlas-one",
]
ROADMAP_HINTS = {
    "mq-mcp": {
        "review runtime": "review-runtime-maintainer",
        "architecture memory": "review-runtime-maintainer",
        "cross-repo responsibility": "review-runtime-maintainer",
    },
    "mq-agent": {
        "mq-mcp review": "mq-mcp-review-orchestration",
        "review runtime integration": "mq-mcp-review-orchestration",
    },
    "repo-signal": {
        "symbolic intelligence": "symbolic-intelligence-exporter",
        "callgraph.json": "symbolic-intelligence-exporter",
        "symbol_index.json": "symbolic-intelligence-exporter",
    },
    "mq-image-analyze": {
        "visual cognition": "visual-architecture-analysis",
        "architecture review": "visual-architecture-analysis",
        "topology": "visual-architecture-analysis",
    },
    "mq-hal": {
        "runtime observability": "runtime-observability-maintainer",
        "vector health": "runtime-observability-maintainer",
        "model health": "runtime-observability-maintainer",
    },
    "atlas-one": {
        "prompt pack": "prompt-pack-maintainer",
        "boundary prompt": "prompt-pack-maintainer",
    },
}
SHARED_SKILL_NAMES = {
    "docs-maintainer",
    "integration-stack-maintainer",
    "release-readiness",
    "repo-aware",
    "semantic-memory-maintainer",
    "terminal-ui-polisher",
    "web-ui-maintainer",
}


@dataclass(frozen=True)
class Skill:
    repo: Path
    path: Path
    name: str | None
    description: str | None


def repo_paths(selected: list[str] | None = None) -> list[Path]:
    names = selected or DEFAULT_REPOS
    paths: list[Path] = []
    for name in names:
        path = Path(name).expanduser()
        if not path.is_absolute():
            path = HOME / name
        if path.exists():
            paths.append(path)
    return paths


def missing_repo_names(selected: list[str] | None = None) -> list[str]:
    names = selected or DEFAULT_REPOS
    missing: list[str] = []
    for name in names:
        path = Path(name).expanduser()
        if not path.is_absolute():
            path = HOME / name
        if not path.exists():
            missing.append(name)
    return missing


def parse_frontmatter(path: Path) -> tuple[str | None, str | None]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None, None
    if not text.startswith("---\n"):
        return None, None
    end = text.find("\n---", 4)
    if end == -1:
        return None, None
    block = text[4:end]
    name = None
    description = None
    for line in block.splitlines():
        if line.startswith("name:"):
            name = line.split(":", 1)[1].strip().strip('"\'')
        if line.startswith("description:"):
            description = line.split(":", 1)[1].strip().strip('"\'')
    return name, description


def find_skills(repo: Path) -> list[Skill]:
    skills: list[Skill] = []
    skills_dir = repo / "skills"
    if not skills_dir.is_dir():
        return skills
    for skill_file in sorted(skills_dir.glob("*/SKILL.md")):
        name, description = parse_frontmatter(skill_file)
        skills.append(Skill(repo=repo, path=skill_file, name=name, description=description))
    return skills


def index_state(repo: Path, skill: Skill) -> str:
    candidates = [repo / "SKILLS.md", repo / "skills" / "platform-skills.md"]
    existing = [candidate for candidate in candidates if candidate.exists()]
    if not existing:
        return "no-index-file"
    rel = skill.path.relative_to(repo).as_posix()
    folder = skill.path.parent.name
    name = skill.name or folder
    for candidate in existing:
        text = candidate.read_text(encoding="utf-8", errors="replace")
        if rel in text or folder in text or name in text:
            return "indexed"
    return "not-indexed"


def roadmap_text(repo: Path) -> str:
    parts = []
    for path in (repo / "ROADMAP.md", repo / "docs" / "ROADMAP.md"):
        if path.exists():
            parts.append(path.read_text(encoding="utf-8", errors="replace").lower())
    return "\n".join(parts)


def audit(args: argparse.Namespace) -> int:
    any_warn = False
    for repo in repo_paths(args.repo):
        skills = find_skills(repo)
        states = [index_state(repo, skill) for skill in skills]
        indexed_count = sum(1 for state in states if state == "indexed")
        print(f"{repo.name}: {len(skills)} skill(s), {indexed_count} indexed")
        for skill, idx in zip(skills, states):
            status = "ok" if skill.name and skill.description else "frontmatter-missing"
            print(f"  - {skill.path.parent.name}: {status}, {idx}")
            if status != "ok" or idx != "indexed":
                any_warn = True

        text = roadmap_text(repo)
        hints = ROADMAP_HINTS.get(repo.name, {})
        for phrase, expected in hints.items():
            if phrase in text and not (repo / "skills" / expected / "SKILL.md").exists():
                any_warn = True
                print(f"  ! roadmap mentions {phrase!r}; missing skill: {expected}")
    return 1 if any_warn and args.fail_on_warn else 0


def validate(args: argparse.Namespace) -> int:
    errors: list[str] = []
    warnings: list[str] = []
    repos = repo_paths(args.repo)
    all_skills: list[Skill] = []
    for missing in missing_repo_names(args.repo):
        warnings.append(f"{missing}: repo not found")

    if args.ecosystem:
        print(f"Ecosystem validation: {len(repos)} repo(s)")

    for repo in repos:
        skills = find_skills(repo)
        all_skills.extend(skills)
        if args.ecosystem and not (repo / "SKILLS.md").exists() and not (repo / "skills" / "platform-skills.md").exists():
            warnings.append(f"{repo.name}: repo has no local skill index")
        for skill in skills:
            folder = skill.path.parent.name
            if not skill.name:
                errors.append(f"{repo.name}/{folder}: missing frontmatter name")
            elif skill.name != folder:
                warnings.append(f"{repo.name}/{folder}: name {skill.name!r} differs from folder")
            if not skill.description:
                errors.append(f"{repo.name}/{folder}: missing frontmatter description")
            elif len(skill.description) > 260:
                warnings.append(f"{repo.name}/{folder}: long description ({len(skill.description)} chars)")
            idx = index_state(repo, skill)
            if idx == "not-indexed":
                warnings.append(f"{repo.name}/{folder}: not referenced by local skill index")
            elif idx == "no-index-file":
                warnings.append(f"{repo.name}/{folder}: repo has no local skill index")

    if args.ecosystem:
        by_name: dict[str, list[str]] = {}
        for skill in all_skills:
            name = skill.name or skill.path.parent.name
            by_name.setdefault(name, []).append(f"{skill.repo.name}/{skill.path.parent.name}")
        for name, owners in sorted(by_name.items()):
            if len(owners) > 1 and name not in SHARED_SKILL_NAMES:
                warnings.append(f"duplicate skill name {name!r}: {', '.join(owners)}")

        for repo in repos:
            text = roadmap_text(repo)
            for phrase, expected in ROADMAP_HINTS.get(repo.name, {}).items():
                if phrase in text and not (repo / "skills" / expected / "SKILL.md").exists():
                    warnings.append(f"{repo.name}: roadmap mentions {phrase!r}; missing skill {expected}")

    for item in warnings:
        print(f"WARN {item}")
        print(f"     fix: {fix_suggestion(item)}")
    for item in errors:
        print(f"FAIL {item}")
        print(f"     fix: {fix_suggestion(item)}")
    if errors:
        print(f"Validation failed: {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"Validation passed: {len(warnings)} warning(s)")
    return 0


def fix_suggestion(message: str) -> str:
    if "missing frontmatter name" in message:
        return "add `name: <folder-name>` to SKILL.md frontmatter"
    if "missing frontmatter description" in message:
        return "add a concise `description:` to SKILL.md frontmatter"
    if "name " in message and " differs from folder" in message:
        return "rename the folder or make frontmatter `name` match it"
    if "long description" in message:
        return "shorten the frontmatter description to 260 characters or less"
    if "not referenced by local skill index" in message:
        return "add the skill to SKILLS.md or skills/platform-skills.md"
    if "repo has no local skill index" in message:
        return "create SKILLS.md and list the repo skills"
    if "repo not found" in message:
        return "clone the repo locally or pass --repo with the correct path"
    if "duplicate skill name" in message:
        return "rename one skill so ecosystem skill names stay unique"
    if "roadmap mentions" in message and "missing skill" in message:
        return "create the expected skill or remove the stale roadmap hint"
    return "inspect the skill folder and update SKILL.md"


def scaffold(args: argparse.Namespace) -> int:
    repo = repo_paths([args.repo])[0] if repo_paths([args.repo]) else Path(args.repo).expanduser()
    if not repo.is_absolute():
        repo = HOME / args.repo
    if not repo.is_dir():
        print(f"Repo not found: {repo}", file=sys.stderr)
        return 2
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.name):
        print("Skill name must be lowercase kebab-case", file=sys.stderr)
        return 2
    skill_dir = repo / "skills" / args.name
    skill_file = skill_dir / "SKILL.md"
    if skill_file.exists() and not args.force:
        print(f"Skill already exists: {skill_file}", file=sys.stderr)
        return 1
    skill_dir.mkdir(parents=True, exist_ok=True)
    title = " ".join(part.capitalize() for part in args.name.split("-"))
    description = args.description or f"Use when working on {title.lower()} in {repo.name}."
    body = f"""---\nname: {args.name}\ndescription: {description}\n---\n\n# {title}\n\nUse this skill when working on {title.lower()}.\n\n## Files To Inspect\n\n- `README.md`\n- `ROADMAP.md`\n- relevant source, docs and tests\n\n## Workflow\n\n1. Inspect the existing repo structure first.\n2. Keep changes scoped to the requested behavior.\n3. Update docs and tests when behavior changes.\n4. Run the lightest useful verification.\n\n## Verification\n\n```bash\ngit diff --check\n```\n"""
    skill_file.write_text(body, encoding="utf-8")
    print(f"Created {skill_file}")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", action="append", help="Repo name/path to inspect; may be repeated")
    sub = parser.add_subparsers(dest="command", required=True)
    audit_p = sub.add_parser("audit", help="List skills and roadmap gaps")
    audit_p.add_argument("--repo", action="append", help="Repo name/path to inspect; may be repeated")
    audit_p.add_argument("--fail-on-warn", action="store_true", help="Exit non-zero on warnings")
    audit_p.set_defaults(func=audit)
    validate_p = sub.add_parser("validate", help="Validate skill frontmatter and indexes")
    validate_p.add_argument("--repo", action="append", help="Repo name/path to inspect; may be repeated")
    validate_p.add_argument("--ecosystem", action="store_true", help="Run cross-repo ecosystem checks")
    validate_p.set_defaults(func=validate)
    new_p = sub.add_parser("new", help="Create a local skill scaffold")
    new_p.add_argument("name")
    new_p.add_argument("--repo", required=True, help="Repo name or absolute path")
    new_p.add_argument("--description", default="")
    new_p.add_argument("--force", action="store_true")
    new_p.set_defaults(func=scaffold)
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
