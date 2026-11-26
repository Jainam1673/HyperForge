# Environment — observed facts (2026-11-26)

Only facts observed on this host are recorded here. These are not claims about
other machines or about future toolchain releases.

## Host

| Item | Observed value | Command |
|---|---|---|
| Kernel | `Linux omarchy 7.2.15-1-omarchy x86_64` | `uname -a` |
| Distribution | Omarchy 4.5.0 (Arch-like) | `/etc/os-release` |
| CPU | Intel Core i5-8265U, 4 cores / 8 threads, x86_64 | `lscpu` |
| Linker | `/usr/bin/cc`, `/usr/bin/gcc`, `/usr/bin/ld` | `which` |
| GPU | NVIDIA GeForce MX230, driver 580.178.04 | `nvidia-smi` |

## Toolchain (pinned in `pixi.toml` / `pixi.lock`)

| Tool | Version | Command |
|---|---|---|
| pixi | 0.85.0 | `pixi --version` |
| Mojo | 1.2.0 (2016d0cd) | `pixi run mojo --version` |
| MAX | 26.7.0 | `pixi run max --version` |

Channels: `https://conda.modular.com/max`, `conda-forge`.
Platform: `linux-64`.

## Verified toolchain behavior

- `pixi run mojo run <file>` compiles and runs a Mojo source file.
- `pixi run mojo build -I src src/main.mojo -o hyperforge` produces an
  x86-64 ELF PIE, dynamically linked against `/lib64/ld-linux-x86-64.so.2`.
- `mojo test` does **not** exist in this release (`mojo: error: no such command 'test'`).
  Tests run through `mojo run` with `TestSuite.discover_tests`.
- `from std.sys import has_accelerator` returns `True` on this host.
- `from std.sys.info import is_nvidia_gpu` is `False` for a host-target build,
  which is expected; it describes the compile target, not the host device.
- Multi-module packages work with `mojo build -I src` and `__init__.mojo` in
  each package directory.
- `UInt64` addition and multiplication wrap on overflow (probed), which makes
  SplitMix64 reproducible in this release.
- `enum` is not supported at module scope in Mojo 1.2.0; state values are
  `comptime` string constants.
- `FileHandle.flush()` does not exist; `close()` flushes.
- `std.os` has no `rename` or `truncate`; `std.pathlib.Path` has no `rename`.
- `Dict` has no `.contains()` method; `key in dict` works.
- Files support append mode `"a"`; repeated opens append.
- `std.math.sqrt`, `std.math.abs`, `std.math.pow`, `Float64("3.25")`, and
  `String.split(",")` work.
- `std.math.is_finite` and `Float64.is_finite()` do not exist; finite checks use
  NaN self-inequality plus a magnitude bound.
- `List.insert(index, value)` and `List.pop()` work (used by kNN).

## Skill-versus-installed-version deltas

The installed Mojo/MAX skills target the latest Mojo. The installed stable
Mojo 1.2.0 differs in these observed ways:

- `guard case ... else:` is not available (the skill shows it as stabilized).
  `if case .Some(x) = opt:` compiles and is used instead.
- `Optional.or_else` is not available on the `Optional[String]` returned by
  `std.os.getenv`; an `if case` binding is used instead.
- `has_nvidia_gpu_accelerator` is not exported by `std.sys.info` in 1.2.0.
- `len(String)` is rejected; use `byte_length()`.
- Module-level `enum`, `FileHandle.flush()`, `std.os.rename`, `std.os.truncate`,
  and `Dict.contains()` are all unavailable in 1.2.0 (see verified behavior above).

Every unfamiliar API is probe-compiled before use; see `TEST_RESULTS.md`.

## MAX dependency note

The `max` conda package (26.7.0) is licensed `LicenseRef-Modular-Proprietary`
and declares Python dependencies (`numpy`, `rich`, `msgspec`, and others). It is
a platform dependency, not HyperForge application code. The HyperForge CLI
itself is first-party Mojo and does not import or run Python.
