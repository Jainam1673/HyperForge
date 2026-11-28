# M24 — MAX serving readiness and Mojo portability contract

This milestone implements the honest adapter boundary for "built and ready to
serve with MAX" and the cross-vendor portability contract the owner requested.
It does **not** claim working MAX inference: the installed toolchain does not
expose a validated native Mojo model-inference interface.

## Honest boundary

`hyperforge serve status` reports:

- `boundary_status: BLOCKED_BY_MAX_INTERFACE`
- `serve_enabled: false`
- `serve_decision: REFUSED_UNVERIFIED_INTERFACE`
- a six-item verification checklist, all `UNVERIFIED`
- a target matrix: NVIDIA `sm_61` and CPU `VERIFIED`; other NVIDIA, AMD, and
  Apple Silicon `NOT_TESTED`
- five source-portability rules

A `serve_status` journal record is appended with the schema, boundary, decision,
and target. No `serve run` command is registered because there is no execution
path to serve — registering one would violate the root directive.

## Why this is the correct "ready" state

MAX CLI presence or a local model artifact does not establish a native Mojo
inference boundary. The checklist names exactly what must be verified before
`serve_enabled` can become true: model load, tokenizer, forward/decode, target
matrix, version/driver evidence, and failure/replay/holdout evidence. Until
those are independently verified, serving is refused rather than faked.

## Portability

Mojo first-party logic is vendor-neutral by construction; no vendor-specific
application call exists. The only verified accelerator target on this host is
NVIDIA `sm_61` (MX230, driver 580.178.04) via the GPU catalogue. AMD and Apple
Silicon are `NOT_TESTED`: no hardware, no driver, no measurements. The contract
records that distinction explicitly, so source portability is never presented
as verified cross-vendor runtime support.

## Verification

`test_m24` (2 unit tests) and `test-serve` (13 integration checks) pass. The
original 24 integration suites and all prior unit tests remain unchanged.
