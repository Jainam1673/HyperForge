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

## D006 — GitHub MCP launcher reads the token from `gh`

`scripts/github-mcp.sh` launches the cached
`ghcr.io/github/github-mcp-server:latest` Docker image and passes
`GITHUB_PERSONAL_ACCESS_TOKEN` obtained at runtime from `gh auth token`. No
token is stored in the repository or in the OpenCode config. The script was
missing at session start, which caused the GitHub MCP connection failure; it was
recreated and the connection was verified after an OpenCode server restart.
