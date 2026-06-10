# CLAUDE.md — proto module session

You are a **module-scoped** Claude session for `gpufleet/proto`. Your context is
this repository plus nothing else. Do not open, read, or edit any other module's
repository.

## What this repo IS

The **contract backbone**: the single source of truth for the versioned
protobuf API/ABI that all gpufleet modules communicate through. Everyone else
vendors these contracts as a **read-only dependency pinned at a fixed tag**.

## Hard rules for this session

1. **Edits are confined to this repo.** Never reach into `semantics/`, `agent/`,
   `rca/`, `cli/`, `controlplane/`, etc. If a task requires changing another
   module, **ABSTAIN** and report a blocker.
2. **A contract change is a contract-change-proposal.** Any change to a `.proto`
   field, enum value, message, or service is a deliberate, reviewed change.
   - Editing/removing/renumbering an existing field or enum value, or changing a
     type, is **breaking** → requires a new package version (`gpufleet.v2`), not
     an in-place edit. Never silently break `gpufleet.v1`.
   - Adding a new field with a fresh field number, a new message, or a new enum
     value at the end is additive/compatible — still proposed and reviewed.
3. **Semver discipline.** This repo is consumed by tag. Tag additive changes as a
   minor bump; never re-tag. Breaking work goes to a new `vN` package + a new
   major tag. Document the change in `CONTRACTS.md`.
4. **Lint/format/breaking must be green.** Before proposing: `buf lint`,
   `buf format --diff` (must be clean), and `buf breaking --against` the base
   branch. CI enforces all three.
5. **Encode the product red lines into the schema, not prose:**
   - Evidence in, Verdict out. `EvidencePack` carries facts + provenance ONLY —
     never prompts, playbooks, thresholds, heuristics.
   - ABSTAIN is the safe default (`FAULT_CLASS_UNSPECIFIED`=0,
     `FAULT_CLASS_ABSTAIN`=1). Keep the ≥2-distinct-`SignalSource` independence
     gate *representable* (CitedSignal carries `source`).
   - `Verdict.narration` is narration-only; never the source of truth.
   - No proprietary/closed error-code semantics — only public XID numbers + raw
     verbatim text.
6. **Generated code is not committed.** `gen/` is gitignored. Don't add stubs.
7. **This repo is OPEN (Apache-2.0).** It never imports or references closed
   module content. The closed controlplane has its own separate `api/` proto.

## Layout

```
schema/gpufleet/v1/signal.proto    EvidencePack (evidence in)
schema/gpufleet/v1/verdict.proto   Verdict      (verdict out)
schema/gpufleet/v1/plugin.proto    PluginService (open probe protocol)
buf.yaml                            modules + lint (STANDARD) + breaking (FILE)
buf.gen.yaml                        Go + Python codegen via remote plugins
CONTRACTS.md                        versioning + breaking policy + vendoring
```

## Commands

```bash
buf lint
buf format -w           # apply formatting
buf format --diff       # CI check
buf breaking --against '.git#branch=main'
buf generate
```
