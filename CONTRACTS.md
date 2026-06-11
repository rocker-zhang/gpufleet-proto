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

## 2a. The PluginProto capability contract (D-0011)

`plugin.proto` hosts the **OPEN collection-capability contract**. It is the
declarative interface by which the closed controlplane drives deeper on-node
collection **without ever shipping code or playbooks**:

- **`CapabilityDescriptor` `{ id, tier, source, params_schema_ref,
  resource_budget, description, version }`** — one entry in the agent's FIXED,
  OPEN, SIGNED, vetted catalog. The controlplane addresses a capability by `id`
  only; the implementation lives in the open agent and is customer-auditable.
- **`CollectDirective` `{ capability_id, params, budget, window, device_uuids }`**
  — the DECLARATIVE instruction the controlplane returns over the agent's
  outbound HTTPS. It carries no code, no playbook, no threshold, no heuristic.
- **`ResourceBudget` `{ max_duration, max_cpu_millicores, max_map_entries,
  max_samples }`** + **`ConsentTier` `{ UNPRIVILEGED (Tier-0),
  PRIVILEGED (Tier-1) }`** — the resource-guard / kill-switch and consent model.
  The agent is the **sole policy enforcer**: it allowlists `capability_id`,
  refuses any tier the customer has not enabled, and clamps every directive to
  the capability's advertised budget.
- **`PluginService` `Describe` / `Collect` / `Health`** is unchanged in shape:
  `Describe` advertises the `catalog` (the discovery handshake), `Collect`
  executes one validated directive read-only, `Health` is liveness. New
  capabilities ship only via **new OPEN agent releases**; the controlplane
  discovers them through `Describe`.

Hard line: the directive flow is response-side only — the agent ALWAYS initiates
outbound, ZERO inbound to the node. The moat (what-to-collect + how-to-interpret)
stays server-side; nodes hold only generic auditable collectors.

## 2b. The shared gate / signature schema (`GateClassSchema`)

The deterministic-gate vocabulary — collectively the **`GateClassSchema`** — is
defined **once** here and shared identically by the open `rca` library and the
closed controlplane. There is **one gate schema, not two**: both sides vendor
these types at the same proto tag and **neither hard-codes its own copy**
(D-0008, TASK-0021). The schema is the three enums + one citation message below,
all under `buf breaking` control (additive-only within `v1`):

- **`SignalSource`** (in `signal.proto`) is the **independence class**. The
  >=2-corroborating-signal gate is judged on **source**: two facts from the same
  source do not corroborate. `CapabilityDescriptor.source`,
  `TimelineEntry.source`, and `CitedSignal.source` all reference this one enum.
- **`FaultClass`** (in `verdict.proto`) is the closed deterministic **outcome
  set** (8–12 classes), with `FAULT_CLASS_UNSPECIFIED`/`FAULT_CLASS_ABSTAIN` as
  the safe defaults and `reserved 12..31` for additive growth.
- **`GateSignature`** (in `verdict.proto`) is the **versioned signature-ID
  registry**: the stable id ⇄ number mapping for the named deterministic rule
  that fired (e.g. `GATE_SIGNATURE_XID79_FALLEN_OFF_BUS`). It is **audit
  metadata only**, never an input to the class decision — the class is decided
  by the gate over `cited_signals`, and `Verdict.signature` records *which* rule
  matched. It carries **no thresholds, no heuristics, no playbook text**; only
  the id mapping is shared, the rule *implementation* stays in `rca`/closed.
  `GATE_SIGNATURE_UNSPECIFIED` is the safe zero (ABSTAIN); `reserved 10..63`
  leaves room for additive growth. New signatures **append at the end** (minor
  tag); never renumber/repurpose (that is a `v2` break).
- **`CitedSignal`** anchors each adjudication to a real `TimelineEntry.signal_id`
  for evidence-grounding.

The single shared source for these types is **this repo's `gpufleet.v1`**:
the open `rca` gate consumes them from `gen/go` at the pinned tag, and the
closed controlplane reuses the SAME generated types — it does not redefine
`FaultClass`/`GateSignature` in its separate closed `api/` proto. A change to
any member of `GateClassSchema` is a **shared-schema change** affecting both the
open gate and the closed engine and MUST be reviewed as such.

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

`make gen` (= `buf generate`, see `Makefile`) emits, with the single managed
`go_package` prefix **`github.com/rocker-zhang/gpufleet-proto/gen/go`**:
- **Go** → `gen/go` (protocolbuffers/go + grpc/go, `paths=source_relative`),
  packaged as a self-contained Go module (`gen/go/go.mod`).
- **Python** → `gen/python` (protocolbuffers/python + pyi + grpc/python).

Codegen policy (split, because Go and Python consumers vendor differently):
- **`gen/go` IS committed** and carried on the tagged tree. Go consumers
  (`semantics`/`agent`/`rca`/`cli`) vendor it read-only via `go.mod` at the
  proto tag (see §4) — so the tag must contain compiled-clean Go. It is
  **generated, not hand-edited**; regenerate with `make gen` after any `.proto`
  change. `make gen` also runs `go build ./...` + `go vet ./...` on `gen/go`.
- **`gen/python` stays gitignored**; Python consumers regenerate via `make gen`
  or pin the published distribution by exact tag (see §4).

The `.proto` files remain the **sole source of truth**; `gen/go` is a derived,
reproducible artifact and any drift is fixed by re-running `make gen`, never by
editing the generated files.

Reproducibility targets (`Makefile`): `make lint` (`buf lint` + `buf format
--diff`, the contract gate), `make gen` (regenerate Go+Python and build Go),
`make breaking` (`buf breaking` vs. `main`).

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
