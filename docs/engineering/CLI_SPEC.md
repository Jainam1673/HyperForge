# CLI specification — implemented subset (M01)

Binary: `hyperforge` (native executable built from `src/main.mojo`).
Results go to stdout; errors and diagnostics go to stderr.

## Syntax

```
hyperforge [--help | --version]
hyperforge doctor [--json]
hyperforge init <path>
hyperforge experiment create <name> [seed]
hyperforge experiment list [--json]
hyperforge experiment show <id> [--json]
hyperforge experiment replay <id>
hyperforge automl inspect <data.csv> <target>
hyperforge automl run <data.csv> <target> [budget] [seed]
hyperforge automl show <id>
hyperforge automl replay <id>
hyperforge automl compare <id-a> <id-b>
hyperforge report <id>
```

`--help`/`-h` and `--version`/`-V` take precedence over other arguments.
`--json` is valid with `doctor`, `experiment list`, and `experiment show`.
Any unknown command, unknown option, or extra positional argument is a usage
error. Experiment commands operate on the workspace in the current directory
and require it to be initialized with `hyperforge init`.

## Commands (registered only when real)

| Command | Behavior | Exit codes |
|---|---|---|
| `--help`, `-h` | Print help, including implemented vs planned commands | 0 |
| `--version`, `-V` | Print `hyperforge 0.1.0 (M02)` | 0 |
| `doctor [--json]` | Print separate capability probes; human or versioned JSON | 0, 3 |
| `init <path>` | Create `hyperforge.toml`, `experiments/`, `artifacts/`, `logs/` | 0, 1, 2 |
| `experiment create` | Write config artifact + journal records; print stable ID | 0, 1, 2 |
| `experiment list` | List experiments from the journal | 0, 1, 2 |
| `experiment show` | Show one experiment and its events | 0, 1, 2 |
| `experiment replay` | Verify config artifact and checksum; no execution | 0, 1, 2, 3 |
| `automl inspect` | Validate CSV and print schema/fingerprint | 0, 1, 2 |
| `automl run` | Run bounded deterministic regression search | 0, 1, 2 |
| `automl show` | List validation and held-out trials | 0, 1, 2 |
| `automl replay` | Recompute and verify recorded held-out result | 0, 1, 2, 3 |
| `automl compare` | Compare held-out RMSE of two experiments | 0, 1, 2 |
| `report <id>` | Render the AutoML terminal report | 0, 1, 2 |

`experiment create` derives three trial seeds from the experiment seed and
records them. The ID is `exp-` plus a 16-digit FNV-1a fingerprint of
`experiment|<name>|<seed>`; the same name and seed are a duplicate (exit 2).

`experiment replay` is deliberately **input verification only**. It returns
exit 3 with a clear message if the config artifact is missing or its checksum
changed. It never claims execution or scientific reproduction; execution is
planned for M02.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Success |
| 1 | Operation failure (including unknown experiment ID) |
| 2 | Usage or validation error |
| 3 | Required dependency/capability unavailable (including replay refusal) |
| 70 | Internal error |
| 130 | Interrupted |

## Machine-readable output

- `doctor --json` → schema `hyperforge-doctor-v1`
- `experiment list --json` → schema `hyperforge-experiment-list-v1`
- `experiment show <id> --json` → schema `hyperforge-experiment-v1`

All JSON is rendered by first-party Mojo code with escaping for `"`, `\`, and
newline. No external serializer is used. The journal itself uses a separate
versioned field format (`HFJ1`), not JSON.
