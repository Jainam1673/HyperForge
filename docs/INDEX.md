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

Engineering state files prescribed by the master directive (`PROJECT_STATE.md`,
`HANDOFF.md`, `ENVIRONMENT.md`, `TEST_RESULTS.md`, and others) do not exist yet. Add
them only when there are observed facts to record.
