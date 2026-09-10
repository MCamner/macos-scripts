---
name: openai-vector-store-refresh
description: Check, refresh, and verify OpenAI vector stores for MQ repos, especially macos-scripts semantic repository memory; use for Codex or Claude sessions that need safe vector-store updates.
---

# OpenAI Vector Store Refresh

Use this skill when the user asks whether an OpenAI vector store is current, asks to update or refresh semantic repository memory, or needs to verify `mq-agent memory` / `file_search` behavior for an MQ repo.

## Scope

This workflow is for OpenAI vector stores and MQ semantic repository memory. It is not for editing mqobsidian notes, rebuilding local-only indexes, or cleaning/deleting OpenAI files unless the user explicitly asks for that destructive action.

## Safety

Refreshing uploads repo-derived content to OpenAI. Before running the upload step, state the repo path and target vector store ID and get explicit approval if the user has not already granted it in the current turn. Never print API keys or `.env` contents.

Deletion or replacement of existing vector-store files is destructive. Prefer the non-destructive MQ flow below unless the user explicitly requests cleanup.

## Preferred MQ Flow

For `macos-scripts`, prefer the `mq-agent` semantic memory commands:

```bash
mq-agent memory status --json
mq-agent memory build /Users/mansys/macos-scripts
mq-agent memory refresh --approve /Users/mansys/macos-scripts
```

If `OPENAI_API_KEY` is missing from the process environment, load it without printing it:

```bash
zsh -lc 'set -a; source ~/.env 2>/dev/null || true; source /Users/mansys/macos-scripts/.env 2>/dev/null || true; set +a; mq-agent memory refresh --approve /Users/mansys/macos-scripts'
```

Use `memory build` as the preview. It should report the intended `repo-signal semantic-upload` action and must not upload.

## Verify Freshness

After refresh, verify both OpenAI metadata and local retrieval:

```bash
mq-agent memory status --json
curl -sS "https://api.openai.com/v1/vector_stores/$VECTOR_STORE_ID" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json"
mq-agent memory search "recent repo-specific terms" --json
```

Report the vector store ID, status, file counts, newest uploaded file, and whether retrieval worked.

For `macos-scripts`, the active store should come from `mq-agent memory status --json`, not old helper-script defaults. Historical scripts may reference an older default store.

## MCP Troubleshooting

If `mq-agent memory search` says no MCP server is reachable, test the server directly:

```bash
lsof -nP -iTCP:8765 -sTCP:LISTEN
curl -sS -m 3 -i http://localhost:8765/health
curl -sS -m 3 -i http://localhost:8765/tools
mq-agent mcp status --json
```

In Codex, Python/httpx-based `mq-agent` checks may fail inside the sandbox with `Operation not permitted` even when `curl` works and the MCP server is healthy. In that case, rerun the `mq-agent mcp status`, `mq-agent mcp tools`, or `mq-agent memory search` check with normal host/network execution rather than treating the server as broken.

Port `8765` is the MQ MCP server. Port `8766` is for `mq-image-analyze` and may be absent without blocking semantic memory.

## Output

Keep the final report short:

- target repo and vector store ID
- preview result
- upload result and OpenAI file ID if available
- vector-store status and file counts
- retrieval/MCP verification result
- any remaining uncertainty, especially sandbox-only failures
