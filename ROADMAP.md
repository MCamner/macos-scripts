# Roadmap

## Near-term

- workflow validation / health checks
- release gate integration (repo-signal publish checklist)
- add mqlaunch shortcuts for mq-mcp review workflows: `mqlaunch review`,
  `mqlaunch architecture`, `mqlaunch risk-review`, `mqlaunch repo-health`
- route cognition-heavy commands through mq-agent/mq-mcp instead of embedding
  review or semantic-memory logic in shell scripts

## Planned

- plugin-style extensions
- remote execution support
- improved onboarding

## Completed

- mqlaunch command surface
- terminal release check workflow
- doctor / system check
- secrets scan via gitleaks
