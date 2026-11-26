# Test results — exact commands and observed outcomes

Environment: see `ENVIRONMENT.md`. Date: 2026-11-26.

## Probe commands (before writing code)

| Command | Outcome |
|---|---|
| `pixi run mojo --version` | `Mojo 1.2.0 (2016d0cd)` |
| `pixi run max --version` | `MAX 26.7.0` |
| `pixi run mojo build /tmp/opencode/mojo_probe.mojo -o ...` | ELF x86-64 executable, exit 0 |
| `pixi run mojo run /tmp/opencode/api_probe.mojo alpha beta` | args, `Path.exists()`, file read/write, `getenv`, `has_accelerator` all work |
| `pixi run mojo run /tmp/opencode/api_probe3.mojo` | `mkdir`, stderr write, `exit(7)` → status 7 |
| `pixi run mojo run /tmp/opencode/test_probe.mojo` | `TestSuite` runs 1 test, status 0 |
| `pixi run mojo test --help` | `error: no such command 'test'` |

Failed probes that corrected the implementation:

- `from std.sys.info import has_nvidia_gpu_accelerator` → module has no such symbol.
- `guard case ... else:` → `use of unknown declaration 'guard'`.
- `getenv("PATH").or_else("")` → `'String' value has no attribute 'or_else'`.
- `len(String)` → rejected; use `byte_length()`.
- `return result` for `CliArgs`/`List[Probe]` → ownership error; use `^`.

## Build and test commands

| Command | Outcome |
|---|---|
| `pixi run build` | exit 0; produced `hyperforge` (93K ELF) |
| `pixi run test` | 13 tests run, 13 passed, 0 failed, 0 skipped |
| `pixi run test-cli` | `integration: 24 passed, 0 failed` |

## Manual CLI checks (binary at `/tmp/opencode/hyperforge`)

| Invocation | Status | Observation |
|---|---:|---|
| `--help` | 0 | help text on stdout, including planned commands |
| `--version` | 0 | `hyperforge 0.1.0 (M00)` |
| `doctor` | 0 | 6 probes; `max_cli` UNAVAILABLE outside pixi env |
| `doctor` via `pixi run` | 0 | `max_cli` OK at `.pixi/envs/default/bin/max` |
| `doctor --json` | 0 | valid single-line JSON with `hyperforge-doctor-v1` schema |
| no arguments | 0 | help text |
| `badcommand` | 2 | stderr: `unknown command: badcommand` |
| `--bogus` | 2 | stderr: `unknown option: --bogus` |
| `init` | 2 | stderr: `init requires a target directory` |
| `init ../escape` | 2 | stderr: `'..' is not allowed` |
| `init /tmp/opencode/ws1` | 0 | config + `experiments/`, `artifacts/`, `logs/` created |
| re-run same `init` | 2 | stderr: `workspace already initialized` |
| `doctor --json extra` | 2 | stderr: `unexpected argument: extra` |

## Clean-checkout reproduction

Copied the repository to `/tmp/opencode/cleanhf` with `.pixi`, the built binary,
and `.git` excluded, then ran:

| Command | Outcome |
|---|---|
| `pixi install --frozen` | environment installed |
| `pixi run build` | exit 0 |
| `pixi run test` | 13 tests run, 13 passed |
| `pixi run test-cli` | `integration: 24 passed, 0 failed` |

An initial attempt failed because the copy command excluded every path named
`hyperforge`, including `src/hyperforge`; using `--exclude='./hyperforge'`
fixed the harness. This was a test-procedure defect, not a project defect.

## Independent verification pass

| Check | Outcome |
|---|---|
| `node -e JSON.parse(...)` on `doctor --json` | valid JSON, 6 probes, all fields present |
| `hyperforge automl run` | exit 2; command is not registered |
| `init` on an existing file | exit 2 with clear stderr message |
| JSON escaping with a `"` in the executable path | parsed correctly by `node` |
| `find src tests -name '*.py'` | no application Python source |
| rebuild with warnings visible | no warnings |

Python files exist only inside installed `.agents/skills` resources; none are
HyperForge application code.

## M01 test results

| Command | Outcome |
|---|---|
| `pixi run test` | 26 tests total (13 CLI + 13 M01), all passed |
| `pixi run test-cli` | `integration: 24 passed, 0 failed` |
| `pixi run test-experiment` | `experiment integration: 17 passed, 0 failed` |
| clean copy: `pixi install --frozen` + all three test tasks | all pass |

M01 probes (before implementation):

| Probe | Outcome |
|---|---|
| `UInt64` max + 1 | `0` (wraps) |
| `UInt64` max * 3 | `18446744073709551613` (wraps) |
| module-level `enum Phase:` | `expressions must not appear at file scope` |
| `f.flush()` | `FileHandle has no attribute 'flush'` |
| `std.os.rename`, `std.os.truncate`, `Path.rename` | all unavailable |
| `Dict.contains()` | unavailable; `key in dict` works |
| append mode `"a"` across two opens | content appended in order |

Independent verification:

| Check | Outcome |
|---|---|
| `node` JSON.parse of `experiment show --json` with name `demo\|a=b\c` | parsed, name preserved exactly |
| duplicate create with same name/seed | exit 2, clear message |
| replay after appending to config artifact | exit 3, checksum refusal |
| corrupt tail line | recovery notice, 2 good records retained |
| unknown version in non-last record | exit 1, journal unchanged |
| `experiment list --json` parsed by `node` | valid JSON |

Two defects found and fixed during M01: the record parser initially split
payload `|` as a record delimiter, and `parse_record` rejected a trailing
newline. Both are covered by unit tests now.

## GitHub MCP verification

| Command | Outcome |
|---|---|
| direct MCP initialize against `scripts/github-mcp.sh` | JSON-RPC initialize response, `github-mcp-server v2.3.0` |
| `opencode mcp list` after server restart | `github  connected` (all four servers connected) |
| `get_me` via GitHub MCP | login `Jainam1673`, id 138559626 |
