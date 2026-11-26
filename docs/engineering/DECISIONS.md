# Engineering decisions

## D001 — Pin Mojo 1.2.0 and MAX 26.7.0 from the stable channel

`pixi.toml` uses `https://conda.modular.com/max` and `conda-forge` with
`mojo >=1.2.0,<2` and `max >=26.7,<27`. Rationale: both versions were observed
installed and working together; stable channel is required for the baseline.
MAX is a platform dependency with a proprietary license and Python package
dependencies; it is not used by the CLI logic. Nightly is excluded.

## D002 — First-party CLI parser, no third-party packages

No argument-parsing, JSON, or CLI library is added. `src/hyperforge/cli/args.mojo`
parses a small deterministic grammar; `doctor` renders its own JSON with
explicit escaping. Rationale: dependency policy defaults to no; the grammar is
small and testable with the standard library.

## D003 — Tests run via `mojo run`, not `mojo test`

The installed Mojo 1.2.0 has no `mojo test` subcommand (observed error). Tests
use `TestSuite.discover_tests[__functions_in_module()]().run()` and are invoked
by `pixi run test`.

## D004 — Stable-version syntax adjustments

The Mojo skills target a newer Mojo than the installed 1.2.0. `guard case` and
`Optional.or_else` are not accepted by this compiler; `if case` with an
explicitly typed `Optional` is used. `len(String)` is replaced by
`byte_length()`. These deltas were found by compile probes, not assumed.

## D005 — Shell is used only for build/test automation

`tests/integration_cli.sh` is a Bash test harness. No HyperForge application
logic is implemented in shell. This follows the directive's allowance for
small build/test automation.

## D007 — Project-owned HFJ1 journal format

The journal stores one record per line:
`HFJ1|<seq>|<type>|<checksum>|<payload>\n`. Payload is `key=value` fields with
escaping for `\`, `|`, `=`, and newline. The checksum is FNV-1a 64 over
`seq|type|payload`. JSON was rejected for the journal because the installed
stdlib has no JSON parser and a second serializer would add complexity; the CLI
JSON renderers are separate and versioned.

## D008 — FNV-1a is an integrity check, not a security hash

FNV-1a detects accidental corruption and truncation, which is the requirement
for local experiment records. It is not collision-resistant and must not be
used for authenticity. This is stated in the source and in `PROJECT_STATE.md`.

## D009 — Tail-only recovery, no atomic rename

An invalid last record (bad checksum, unknown version, bad sequence, duplicate
ID, or missing newline) is dropped and the validated prefix is rewritten. An
invalid record in the middle is a hard error and the file is untouched.
Installed Mojo 1.2.0 has no `rename` or `truncate`, so recovery is a plain
full-file write; this limitation is explicit rather than claimed as atomic.

## D010 — SplitMix64 and deterministic seed derivation

SplitMix64 with wrapping `UInt64` arithmetic provides reproducible streams.
`derive_seed(base, namespace, index)` is a pure FNV-1a hash of a canonical key,
so recorded seeds can reproduce derived streams without storing all of them.

## D011 — Defer candidate/metric/budget structs to M02

M01 implements the types needed by real behavior. Candidate, metric, budget,
and acceptance structs would have no execution path until AutoML trials exist;
they are deliberately deferred, not forgotten.

## D012 — GitHub MCP launcher reads the token from `gh`

`scripts/github-mcp.sh` launches the cached
`ghcr.io/github/github-mcp-server:latest` Docker image and passes
`GITHUB_PERSONAL_ACCESS_TOKEN` obtained at runtime from `gh auth token`. No
token is stored in the repository or in the OpenCode config. The script was
missing at session start, which caused the GitHub MCP connection failure; it was
recreated and the connection was verified after an OpenCode server restart.
