# Milestone acceptance evidence

## M00 — Toolchain, project bootstrap, and CLI shell

Directive: master build prompt §9/M00; blueprint §7/M00.

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Verified pinned Mojo/MAX environment | `ENVIRONMENT.md`; `pixi run mojo --version` → 1.2.0; `pixi run max --version` → 26.7.0 | PASS |
| Minimal build/run/test commands | `pixi.toml` tasks `build`, `run`, `test`, `test-cli` | PASS |
| Native executable entry point | `pixi run build` → `hyperforge` (ELF x86-64, 93K) | PASS |
| CLI parser with help/version | unit tests + integration checks | PASS |
| `doctor` with separate capability probes and truthful statuses | probe list in `CLI_SPEC.md`; integration checks | PASS |
| Minimal `init` workspace operation | integration check creates config + 3 dirs | PASS |
| Errors and exit codes tested | integration checks for codes 0 and 2; 24 checks | PASS |
| CPU-only CLI works without GPU/model | probes report `NOT_TESTED`/`UNAVAILABLE` without fatal exit | PASS |
| No Python source or unapproved app packages | source tree contains only `.mojo` application files; TOML/shell only for build/test | PASS |
| Clean checkout reproduces setup | fresh copy: `pixi install --frozen`, `build`, `test`, `test-cli` all pass | PASS |
| Independent verification pass | JSON parsed by `node`; planned commands reject; file target rejects; quote-in-path JSON escaping; clean rebuild with no warnings | PASS |

### Workflow closure

- Commit: `ca44ece6d8290b168eeffc72b6cadd1ce5533ad8`
- Pushed to `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP verified working before the push.

M00 implementation and evidence are **VERIFIED** and the milestone is pushed.

## M01 — Core experiment and evidence substrate

Directive: master build prompt §9/M01; AGENTS.md §8 and M01; blueprint §9.

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Typed experiment/candidate/trial/metric/error/budget types | M01 adds typed `Experiment`, `Field`, `JournalRecord`, `JournalReadResult`; state constants; status labels. Candidate/dataset/metric/budget/error/acceptance structs are DEFERRED to M02, where execution first needs them, under the directive's no-speculative-abstraction rule | DEFERRED (justified) |
| Append-only versioned journal with checksums | `HFJ1` format, FNV-1a checksum, `experiment`/`event` record types; round-trip and tamper tests | PASS |
| Recovery from truncated/corrupt last record | unit tests for corrupt tail, truncated tail, duplicate ID; integration check | PASS |
| Atomic artifact writes | config artifact written in one `write` + `close`; no rename available | DOCUMENTED LIMITATION |
| Integrity hashes and provenance | config checksum recorded and verified by replay | PASS |
| Status transitions with invalid transitions rejected | `state_machine.mojo` tests | PASS |
| Seeded RNG and seed derivation | SplitMix64 known-value and determinism tests | PASS |
| Stable machine-readable output | 3 versioned JSON schemas, parsed by `node` in verification | PASS |
| Persistence survives process restart | create/list/show/replay across separate processes; integration script | PASS |
| Round trips preserve records and stable IDs | experiment field round-trip test | PASS |
| Replay refuses missing data/config | exit 3 for missing and tampered config artifact | PASS |
| No database server or external storage service | journal is a local file under `experiments/` | PASS |
| Independent verification | adversarial names with `|`, `=`, `\`; duplicate create; JSON parsed; clean-copy reproduction | PASS |
| Clean checkout reproduction | fresh copy: install, build, 26 unit tests, 24 CLI checks, 17 experiment checks | PASS |

### Deferred within M01

Candidate, metric, budget, and acceptance structs are not created yet because
no execution path uses them; the directive says not to build speculative
abstractions. They will be introduced with M02 when AutoML trials need them.

M01 implementation and evidence are **VERIFIED**; commit/push is the remaining
workflow action.
