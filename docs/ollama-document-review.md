# Ollama Document Review

Local review helper for improving comments, docstrings, function descriptions,
and script section headers using a local Ollama model.

Available from:

```text
mqlaunch → 7. Document functions → 8. Ollama review
```

Or run directly:

```bash
tools/scripts/ollama-document-review.py tools/scripts/document-functions.sh
tools/scripts/ollama-document-review.py terminal/menus/ --model qwen3:4b
```

## What it does

- Reads selected `.sh`, `.bash`, `.zsh`, and `.py` files
- Sends content to local Ollama
- Prints up to five high-signal documentation/comment suggestions per file
- Focuses on purpose, side effects, exit behavior, and smoke-test contracts
- **Does not modify files**
- **Does not commit changes**

## Default model

```bash
qwen3:4b
```

Override with:

```bash
MQ_OLLAMA_REVIEW_MODEL=qwen3:4b-instruct mqlaunch
```

## Safety

Skips common secret-like filenames (`.env`, `id_rsa`, `token`, etc.) and only
reviews supported source extensions. Never writes or executes code suggestions.
