# proto — module brief (CLAUDE.md)

## 1. 身份

- **class**: OPEN (Apache-2.0).
- **language**: Protocol Buffers (proto3); codegen targets Go + Python.
- **kind**: contracts (shared schema / ABI source of truth — *not* a daemon/service).
- **purpose**: the single versioned protobuf contract backbone every gpufleet
  module communicates through (EvidencePack in, Verdict out, PluginService +
  capability catalog).
- **on-path | bypass | shared-lib**: shared contract; consumed read-only by all
  modules. Not itself on any data path.

## 2. 在系统里的位置

- **Produces** (the contracts others vendor by tag):
  - `signal.proto` — **EvidencePack** (evidence IN): normalized, off-path,
    read-only window of facts + provenance. Carries `SignalSource` (the
    independence class) and `TimelineEntry.signal_id` (citation anchor).
  - `verdict.proto` — **Verdict** (verdict OUT): `FaultClass` (ABSTAIN-by-default),
    `CitedSignal` (>=2 distinct `SignalSource`), `narration` (narration-only),
    `CostImpact` (deterministic $ attribution).
  - `plugin.proto` — **PluginService** (Describe/Collect/Health) + the **D-0011
    capability model**: `CapabilityDescriptor` / `CollectDirective` /
    `ResourceBudget` / `ConsentTier`.
- **Consumes**: only `google/protobuf` well-known types. Imports nothing from
  other modules; the closed controlplane keeps its OWN separate `api/` proto.
- **Edges** (read-only, pinned by tag): `semantics`, `agent`, `rca`, `cli`
  (Go), `bench` (Python), `controlplane` (Go+Python, evidence-in / verdict-out
  only). The gate's shared class/signature schema (`SignalSource`, `FaultClass`,
  `CitedSignal`) is hosted here and reused identically by the open `rca` library
  and the closed controlplane — there is one gate schema, not two.
- See `../ARCHITECTURE.md` for the full system map and D-0008/0009/0010/0011.

## 3. 继承的红线

Inherits `../RULES.md`. Module-specific hard lines:

1. **Read-only to all consumers.** Nobody edits this repo in passing. A change
   to any `.proto` field/enum/message/service is a deliberate, reviewed
   **contract-change-proposal** (see `CONTRACTS.md`).
2. **Semver + buf breaking.** Tags are the unit of consumption and are
   immutable. Additive change → minor tag; breaking change → a NEW package
   `gpufleet.vN+1` side-by-side, never an in-place `v1` mutation. `buf lint`,
   `buf format --diff`, `buf breaking` must be green.
3. **Hosts the shared gate schema + PluginProto capability contract.** The
   `SignalSource` independence class, `FaultClass` set, and `CitedSignal`
   citation shape are defined ONCE here and shared open/closed. The PluginProto
   `Describe`/`Collect`/`Health` + `CapabilityDescriptor`/`CollectDirective`
   capability catalog is the single open collection-capability contract (D-0011).
4. **Encode red lines into the schema, not prose:** evidence-in/verdict-out;
   EvidencePack carries facts + provenance ONLY (never prompts/playbooks/
   thresholds/heuristics); ABSTAIN is the safe zero value; `narration` is
   narration-only; `CollectDirective` is declarative (capability id + params +
   budget) and carries NO code/playbook; only public XID numbers + raw verbatim
   text (no proprietary/closed error-code semantics).
5. **Generated code is derived, never hand-edited** (regenerate via `make gen`).
   `gen/go` IS committed (Go consumers vendor it read-only at the tag via
   `go.mod`); `gen/python` stays gitignored. The `.proto` files are the sole
   source of truth — see `CONTRACTS.md §5`.
6. **Open, never imports closed content.** The closed controlplane `api/` proto
   is separate and never shares history with this repo.

## 4. 当前任务 & 里程碑焦点

- Milestone **M1** (契约切版): finalize the three `gpufleet.v1` contracts, keep
  `buf lint`/`format`/`breaking` green in CI, cut tag `v0.1.0`, ship consumable
  Go (`gen/go`) + Python gen. Relevant `ops/BOARD.md` cards: proto contract
  finalization + capability-model (D-0011) schema. See `ROADMAP.md`.
- Latest schema work: `plugin.proto` now expresses the D-0011 capability model
  (`CapabilityDescriptor`, `CollectDirective`, `ResourceBudget`, `ConsentTier`)
  while keeping `Describe`/`Collect`/`Health`.

## 5. 构建与测试

```bash
source ../.envrc            # FIRST — project-local toolchain (./.tools, ./.cache)
buf lint                    # STANDARD ruleset (see buf.yaml)
buf format -w               # apply formatting
buf format --diff           # CI check (must be clean)
buf breaking --against '.git#branch=main'
buf generate                # Go + Python into gen/ (gitignored)
```

CI: one workflow runs `buf lint` + `buf format --diff` + `buf breaking` on every
PR; all three must be green before a contract-change-proposal can merge.

## 6. session 工作规则

- **Edits confined to this repo.** Never reach into `semantics/`, `agent/`,
  `rca/`, `cli/`, `controlplane/`, etc.
- **Proto is read-only to consumers**; if another module *needs* a contract
  change, that module session **ABSTAINS** and files a blocker — the change
  arrives here only as an orchestrator-driven contract-change-proposal PR
  reviewed by a non-proposer (see `CONTRACTS.md §3`).
- If a task requires touching another module or a contract change you cannot
  scope cleanly, **abstain and report the blocker** rather than guess.
- **Provenance**: personal hardware/time only; no externally-sourced content,
  no closed error-code semantics.

## 7. 模块路线图

- **M0**: repo init, three `gpufleet.v1` stubs, buf CI skeleton. ✅
- **M1**: finalize signal/verdict/plugin contracts (incl. D-0011 capability
  model); buf lint+format+breaking green; cut `v0.1.0`; Go+Py gen consumable.
- **M2**: additive fields the agent/cli wedge needs (cost/MFU provenance,
  PromQL-source provenance per D-0009); minor tag.
- **M3**: additive support for the 4 deterministic signatures + abstain
  citation shape used by `rca`/`lab`; minor tag.
- **M4**: additive fields for benchmark grounding (evidence-grounding /
  precision@fired surfaces) if needed by `bench`/`eval-corpus`; minor tag.
- **M5**: stabilize the open Verdict + small aggregation envelope (D-0010) that
  the closed controlplane returns; freeze the open wire the paid fleet view
  rides on; minor tag.
- **M6**: contract hardening from partner feedback; cut `v1.0.0` once the
  open wire is validated end-to-end. No breaking change without a `v2` package.

See `ROADMAP.md` for per-milestone exit criteria.
