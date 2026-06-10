# CONTRACTS.md — versioning & vendoring policy for `gpufleet/proto`

This document is the rulebook for changing and consuming the gpufleet contracts.
It is binding on every module session and on the orchestrator's review.

## 1. Package & versioning model

- All current contracts live in package **`gpufleet.v1`** under
  `schema/gpufleet/v1/`.
- The package version (`vN`) is the **major ABI version**. A breaking change
  does NOT mutate `v1`; it introduces `gpufleet.v2` in `schema/gpufleet/v2/`,
  shipped **side-by-side** so existing consumers keep building. `v1` is removed
  only after every consumer has migrated and re-pinned.
- Git **tags are the unit of consumption.** Tags are immutable; never re-tag.
  - Additive/compatible change → new **minor** tag (e.g. `v1.3.0`).
  - New major package version → new **major** tag (e.g. `v2.0.0`).
  - Doc/CI-only change → **patch** tag.

## 2. What is breaking vs. compatible

Enforced mechanically by `buf breaking` (rule set `FILE`) in CI.

**Compatible (allowed in `vN`, additive, still reviewed):**
- Adding a new message or a new RPC.
- Adding a field with a brand-new, never-used field number.
- Adding an enum value with a new number **at the end** of the enum.
- Adding a comment.

**Breaking (NOT allowed in `vN` — requires `v(N+1)`):**
- Removing/renaming a field, message, enum, enum value, or RPC.
- Changing a field number, type, label, or `json_name`.
- Renumbering or repurposing an existing enum value.
- Moving a field into/out of a `oneof`.
- Reusing a `reserved` number for a new meaning.

Reserved ranges (e.g. `FaultClass` reserves `12..31`) exist precisely so future
additive growth does not collide with old wire values. Never reuse a number for
an unrelated meaning.

## 3. Contract-change-proposal process

1. A module session that needs a contract change **ABSTAINS** and files a
   blocker — it does **not** edit this repo.
2. The orchestrator opens a **contract-change-proposal PR** here describing:
   the motivating consumer(s), compatible vs. breaking classification, and the
   target tag.
3. A **Reviewer** session (never the proposer) checks: boundary compliance
   (evidence-in/verdict-out, narration-only, ABSTAIN-by-default representable),
   contract conformance, determinism, no externally-sourced semantics, and that
   `buf lint` / `buf format --diff` / `buf breaking` are green.
4. On merge, the orchestrator tags per §1 and records the change in
   `ops/DECISIONS.md` and the module's `ops/CONTRACTS.md` registry.

## 4. How modules vendor the contracts

Modules depend on a **fixed tag**, read-only. Two supported mechanisms:

### Go modules (`semantics`, `agent`, `rca`, `cli`)
Consume the generated Go from a published, tagged path and pin in `go.mod`:

```
require github.com/gpufleet/proto vX.Y.Z
```

Re-pin only via a deliberate bump PR. Modules MUST NOT run `buf` against a
floating ref or vendor an untagged checkout.

### Python modules (`bench`, controlplane Python side)
Pin the generated distribution by exact version (the tag) in the module's
`pyproject.toml` / `uv` lock. No floating refs.

### buf-native consumers
May add this repo as a buf dependency pinned to a tag in their own `buf.yaml`
`deps:` — but they still treat it as read-only; they never edit it.

## 5. Codegen

`buf.gen.yaml` emits:
- **Go** → `gen/go` (protocolbuffers/go + grpc/go, `paths=source_relative`).
- **Python** → `gen/python` (protocolbuffers/python + pyi + grpc/python).

Generated code is **gitignored**; it is produced at publish/build time, never
committed, so the source of truth stays the `.proto` files alone.

## 6. Dependency graph (who consumes what)

```
                 proto (this repo, gpufleet.v1)
                   │  read-only, pinned by tag
   ┌───────────┬───┴────┬─────────┬───────────┬─────────────┐
 semantics   agent     rca       cli        bench       controlplane
   (Go)      (Go)    (Go)        (Go)      (Python)      (Go+Python)
                                                          consumes EvidencePack
                                                          (in) / Verdict (out);
                                                          its OWN closed api/
                                                          proto is separate.
```

The closed `controlplane` exposes a **separate, closed** `api/` proto for its
internal gRPC/HTTP surface. That closed proto is NOT in this repo and never
shares history with it.
