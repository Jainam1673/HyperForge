# Owner scope directive — full breadth of every technology (2026-11-28)

The owner clarified the intended end state after M23:

1. **Every technology must contain everything reasonably possible within it** —
   not just AutoML and AutoLLM. Specifically:
   - **AutoAI** = AutoML + AutoDL + AutoRL + AutoGenAI + AutoLLM, each full.
   - **SciAI** = SciML + SciDL + SciRL + SciGenAI + SciLLM + SciTransformers
     + SINN, each full.
   - **Agentic** and **World Models** are first-class capabilities, each full.
   - **HPC** must include everything the toolchain can honestly support.
   - Every keyword must include every algorithm, technique, and tool that fits
     it — bounded by what can actually be executed and verified.
2. **The whole project should be built and ready to serve with MAX.**
3. **Mojo was chosen for portability** so the engine can run on NVIDIA, AMD,
   and Apple Silicon.

## Non-negotiable interpretation constraints

These are not objections to the goal; they are the conditions under which the
goal can be claimed truthfully. They come from the root `AGENTS.md`.

- **"Everything possible" is finite per technology, not infinite.** Before each
  monolithic milestone, the declared inventory for that technology is written
  into `EXPANSION_ROADMAP.md`. Completeness means every item in that inventory
  has a real, tested execution path — never an unbounded promise.
- **MAX serving cannot be claimed as working in this environment.** The
  validated native Mojo boundary to MAX model inference does not exist here
  (`BLOCKED_BY_MAX_INTERFACE`). What can be built now is an honest adapter and
  readiness contract: detection, capability reporting, a refusal path when the
  boundary is absent, and a versioned checklist for what must be verified
  before `serve` is enabled. The command surface will report the block, not
  fake inference.
- **Cross-vendor portability is a source-level property, not a verified
  runtime claim.** First-party Mojo avoids vendor-only application code, but
  only the NVIDIA `sm_61` target has been executed on this host. AMD and Apple
  Silicon targets are `NOT_TESTED` until run on that hardware. No performance
  or correctness claim is made for them. The portability contract records
  which targets are verified, which are blocked, and why.
- **Keywords blocked on MAX inference** (AutoGenAI, SciLLM, SciGenAI) keep a
  registered *status* surface but no fake execution path until the interface
  is verified.

## Ordered monolithic program (revised)

| Milestone | Technology | Scope |
|---|---|---|
| M22 | AutoML | ✅ complete — 18 algorithms, full metrics, k-fold |
| M23 | AutoLLM | ✅ complete — first-party PreTrain→Infer lifecycle |
| M24 | MAX readiness + portability | adapter, honest block, vendor contract |
| M25 | AutoDL + AutoTransformers + HPO/NAS | structural search breadth |
| M26 | AutoRL | algorithms, environments, safety evaluation breadth |
| M27 | SciAI breadth | SciML, SciDL, SciRL, SINN, SciTransformers, UQ, differentiable simulation |
| M28 | Agentic + World Models | bounded roles, contracts, transition models |
| M29 | HPC + cross-vendor execution | memory, parallelism, verified target matrix |
| M30 | SciLLM/SciGenAI/AutoGenAI | only after MAX boundary is verified; otherwise explicit block |

Order changed from the earlier plan because the owner explicitly prioritized
MAX readiness and Mojo portability. The reason is recorded here per the master
directive. Every milestone still has one accountable owner, independent
verification, and its own evidence gate.
