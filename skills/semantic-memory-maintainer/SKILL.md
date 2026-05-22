---
name: semantic-memory-maintainer
description: Use when maintaining OpenAI vector stores, semantic repository memory, knowledge packs, indexed markdown, file_search sources, or repo memory freshness across projects.
---

# Semantic Memory Maintainer

Maintain high-signal semantic memory for repositories and assistants.

## When to use

Use this skill when the user asks to:

- upload, refresh, inspect, or clean OpenAI vector stores
- decide what files should be included in semantic repository memory
- create or update a knowledge pack
- remove stale or duplicate vector-store files
- compare local repo content against indexed OpenAI Storage files
- debug `file_search`, `mqlaunch ask`, `mqlaunch srm`, or repo-memory behavior
- document vector store IDs, upload scripts, or memory policy

## Core rule

Semantic memory should be useful, current, and sparse.

Prefer high-signal markdown, entrypoints, architecture notes, command references, tests that explain behavior, and explicit memory manifests. Avoid bulk assets, generated noise, secrets, cache files, binary files, and low-value duplicates.

## Safety

Never print API keys or secrets.

Before deleting files from OpenAI Storage or a vector store, identify the target store and summarize what will be removed. Use dry-run or list-only checks when available. Treat cleanup as destructive.

## Inspection order

1. local repo docs and memory manifests
2. upload scripts and env var names
3. current vector store IDs in docs, scripts, and `.env` keys without printing secret values
4. OpenAI Storage file metadata
5. vector store file counts and indexing status
6. a small file_search query to verify what the memory actually retrieves

## Inclusion guidance

Good candidates:

- `README.md`, `CHANGELOG.md`, `ROADMAP.md`
- architecture, command, release, and troubleshooting docs
- `SKILL.md` files and small reference markdown files
- CLI entrypoints and important scripts when they explain behavior
- tests that encode important contracts
- generated manifests such as `repo-tree.md` or `vector-store-manifest.md`

Usually exclude:

- secrets and `.env` values
- screenshots, images, archives, binaries
- `.DS_Store`, caches, build outputs, virtualenvs
- generated HTML when a markdown source exists
- duplicate backups unless explicitly needed for history

## Maintenance workflow

1. Identify the target vector store and project.
2. List existing Storage/vector-store files by filename and count.
3. Compare against local high-signal files.
4. Upload missing or changed files with stable descriptive filenames.
5. Attach uploaded files to the target vector store.
6. Poll indexing until completed or failed.
7. Run a small retrieval query that proves the new memory is findable.
8. Record IDs or policy changes in the appropriate repo docs if requested.

## Output

Report:

- target vector store name and ID
- files uploaded, attached, skipped, or removed
- indexing status
- verification query result
- any uncertainty about stale duplicates or ownership

