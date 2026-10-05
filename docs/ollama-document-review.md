# Ollama Document Review

Local review helper for improving comments, docstrings, function descriptions,
and script section headers using a local Ollama model.

Available from:

```text
mqlaunch → 7. Document functions → 8. Ollama review
```

Or run directly:

```bash
mqlaunch ollama-review tools/scripts/document-functions.sh
mqlaunch ollama-review terminal/menus/ --model qwen3:4b-instruct
tools/scripts/ollama-document-review.py tools/scripts/document-functions.sh
```

## What it does

* Reads selected `.sh`, `.bash`, `.zsh`, and `.py` files
* Sends content to local Ollama
* Prints up to five high-signal documentation/comment suggestions per file
* Focuses on purpose, side effects, exit behavior, and smoke-test contracts
* **Does not modify files**
* **Does not commit changes**

## Default model

```bash
qwen3:4b-instruct
```

Override with:

```bash
MQ_OLLAMA_REVIEW_MODEL=another-local-model mqlaunch ollama-review .
```

## Keep-alive

The model stays loaded for `30m` after a run (Ollama's own default is 5m), so
a second review within that window skips the cold load.

```bash
mqlaunch ollama-review --keep-alive 0 .        # unload right after the run
MQ_OLLAMA_REVIEW_KEEP_ALIVE=-1 mqlaunch ollama-review .  # keep loaded
```

Bare integers are seconds; other values are durations such as `10m` or `1h`.

## Safety

Skips common secret-like filenames (`.env`, `id_rsa`, `token`, etc.) and only
reviews supported source extensions. Never writes or executes code suggestions.
