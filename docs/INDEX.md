# HyperForge documentation index

This folder holds the project's design and build directives. `AGENTS.md` stays at the
repository root because agent harnesses auto-load it from there; it is the concise
agent contract and links into the detailed documents here.

## Source-of-truth order

Observed execution and tests > current source and configuration > these documents >
historical discussion. These files describe intent and constraints; they do **not**
prove that any capability has been implemented.

## Documents

| Document | Purpose |
|---|---|
| [`HYPERFORGE_MOJO_MAX_MASTER_BUILD_PROMPT.md`](HYPERFORGE_MOJO_MAX_MASTER_BUILD_PROMPT.md) | Authoritative build directive: milestones M00–M21, AutoAI/SciAI families, three discovery loops, CLI specification, acceptance gates, and the "complete" definition. |
| [`MOJO_MAX_BOOTSTRAP_BLUEPRINT.md`](MOJO_MAX_BOOTSTRAP_BLUEPRINT.md) | Fresh-start architecture blueprint: CLI contract, target source tree, first seven milestones, evidence store, and benchmark protocol. |

## Related locations

- `../AGENTS.md` — root agent contract (Mojo-only, CLI-only, no fabricated capability).
- `../.agents/skills/` — project-local Mojo/MAX skills (11 skills) that take priority over remembered syntax.
- `../pixi.toml`, `../pixi.lock` — environment manifest and lock file.

## Engineering state

Observed facts live in `engineering/`:

| Document | Purpose |
|---|---|
| `engineering/PROJECT_STATE.md` | Verified status of implemented capabilities. |
| `engineering/HANDOFF.md` | Current state, blockers, and exact next action. |
| `engineering/MILESTONES.md` | Acceptance criteria and evidence per milestone. |
| `engineering/TEST_RESULTS.md` | Exact commands, versions, outcomes, and limits. |
| `engineering/ARCHITECTURE.md` | Implemented module map, evidence format, and coupling boundaries. |
| `engineering/CAPABILITY_MATRIX.md` | Status of every AutoAI/SciAI keyword, including partial and blocked items. |
| `engineering/RELEASE.md` | Pinned toolchain, clean-checkout commands, licensing, and reliability notes. |
| `engineering/DECISIONS.md` | Dependency and architecture decisions with reasons. |
| `engineering/ENVIRONMENT.md` | Observed host and toolchain facts. |

Source files and test evidence are authoritative over these documents when they
disagree.
