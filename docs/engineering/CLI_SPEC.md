# CLI specification — implemented subset (M00)

Binary: `hyperforge` (native executable built from `src/main.mojo`).
Results go to stdout; errors and diagnostics go to stderr.

## Syntax

```
hyperforge [--help | --version]
hyperforge doctor [--json]
hyperforge init <path>
```

`--help`/`-h` and `--version`/`-V` take precedence over other arguments.
`--json` is valid only with `doctor`. Any unknown command, unknown option, or
extra positional argument is a usage error.

## Commands (registered only when real)

| Command | Behavior | Exit codes |
|---|---|---|
| `--help`, `-h` | Print help, including implemented vs planned commands | 0 |
| `--version`, `-V` | Print `hyperforge 0.1.0 (M00)` | 0 |
| `doctor [--json]` | Print separate capability probes; human or versioned JSON | 0, 3 |
| `init <path>` | Create `hyperforge.toml`, `experiments/`, `artifacts/`, `logs/` | 0, 1, 2 |

`doctor` probes: `executable`, `toolchain_pin`, `max_cli`, `accelerator`,
`workspace`, `model_artifacts`. Statuses are `OK`, `PINNED`, `UNAVAILABLE`, and
`NOT_TESTED`. A missing GPU or MAX CLI does not prevent CPU-only CLI use.
`doctor` returns 3 only if the workspace is not writable.

`init` rejects a target containing `..`, an existing non-directory target, and
an already-initialized workspace, each with a stderr message and exit 2.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Success |
| 1 | Operation failure |
| 2 | Usage or validation error |
| 3 | Required dependency/capability unavailable |
| 70 | Internal error |
| 130 | Interrupted |

## Machine-readable output

`doctor --json` emits schema `hyperforge-doctor-v1`:

```json
{"schema":"hyperforge-doctor-v1","version":"0.1.0","milestone":"M00",
 "probes":[{"name":"...","status":"...","detail":"..."}]}
```

The JSON encoder is first-party Mojo with escaping for `"`, `\`, and newline.
No external serializer is used.
