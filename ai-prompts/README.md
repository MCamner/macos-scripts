# AI Prompts

This library contains reusable prompt templates for analysis, decisions, research, troubleshooting, and direct reasoning.

The folder works like a small prompt system:

- `00-index.txt` helps route you to the right prompt
- `01-00-atlas-analysis.txt` handles routing and execution-path selection
- `01-17-atlas-one.txt` is used for direct, unified reasoning
- the remaining files are specialized engines for specific tasks

## Purpose

The goal is to make strong AI instructions reusable and consistent.

Use `ai-prompts/` when you want to:

- start from a proven prompt instead of writing from scratch
- choose the right reasoning mode for a task
- get more consistent response structure from AI
- build a simple Prompt Operating System for different types of work

## Contents

```text
ai-prompts/
├── 00-index.txt                 # route to the right prompt
├── 01-00-atlas-analysis.txt     # analysis and routing engine
├── 01-09-prompt-debugger.txt    # improve and debug prompts
├── 01-11-decision.txt           # decisions and trade-offs
├── 01-12-research.txt           # research synthesis
├── 01-13-root-cause.txt         # root cause analysis
├── 01-14-problem-solving.txt    # problem solving
├── 01-17-atlas-one.txt          # unified direct engine
├── 01-18-auto-mode.txt          # automatic execution-mode selection
└── README.md
```

## Quick Guide

Use `00-index.txt` when you want the fastest route to the right prompt.

Rule of thumb:

- use `01-00-atlas-analysis.txt` when the task needs routing, multiple steps, or a defined execution path
- use `01-17-atlas-one.txt` when you want a direct answer with strong reasoning
- use the specialized files when you already know the task type

## Examples

Direct reasoning:

```text
/one Help me choose between two product strategies for next quarter.
```

Routing and planning:

```text
/atlas I need to untangle a complex team problem and find the best next step.
```

Prompt improvement:

```text
Use 01-09-prompt-debugger.txt to improve this prompt...
```

## Design Principles

- simple structure over complexity
- clear output over fluff
- specialized prompts for recurring work patterns
- Swedish by default, unless the prompt says otherwise

## Best Use Cases

`ai-prompts/` works especially well for:

- idea generation
- analysis
- decision-making
- research
- problem solving
- prompt design
- coaching and learning

If you keep returning to the same kinds of AI tasks, this is the right place to build on.
