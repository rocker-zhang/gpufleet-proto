# proto — module roadmap (M1..M6)

Module-local milestone breakdown for `gpufleet/proto`. Mirrors `../ops/PLAN.md`
and this module's `CLAUDE.md §7`. proto only ever ships **additive** changes
within `gpufleet.v1`; a breaking need forces a side-by-side `gpufleet.v2`
package (see `CONTRACTS.md`). Discipline: contract changes land as their own
orchestrator-reviewed PR; tags are immutable; `buf lint`/`format --diff`/
`breaking` must be green before any tag.

| Milestone | This module delivers | Exit criteria |
|---|---|---|
| **M1** | Finalize the three `gpufleet.v1` contracts — `signal.proto` (EvidencePack), `verdict.proto` (Verdict + gate schema), `plugin.proto` (PluginService + D-0011 capability model). Cut first tag. | `buf lint` + `buf format --diff` + `buf breaking` green in CI; `buf generate` emits consumable Go (`gen/go`) + Python; **tag `v0.1.0`** cut; `semantics` can vendor and build against it. |
| **M2** | Additive fields for the read-only agent + CLI **money wedge**: ensure `DeviceJobMapping` cost/MFU inputs and D-0009 ingestion provenance (Prometheus-query vs DCGM-scrape source, scrape-interval) are representable in `EvidencePack.provenance` / `SignalSource`. | agent emits a real EvidencePack and cli renders job-level MFU + wasted-$ using only `gpufleet.v1`; any new fields are additive minor tag; no breaking diff. |
| **M3** | Additive support for the 4 deterministic signatures (XID79 / ECC / NVLink / NCCL-timeout) and the **abstain** citation shape: confirm `CitedSignal` + `SignalSource` express the >=2-INDEPENDENT-source gate and that ABSTAIN can cite considered signals. | `rca` implements all 4 signatures (1 signal → abstain, 2 distinct sources → fire, FP=0) against the contract with no schema gap; minor tag if fields added. |
| **M4** | Additive fields (if any) the public benchmark needs for **evidence-grounding** and precision@fired/abstention-correctness scoring; keep `signal_id` citation resolvable end-to-end. | `bench` harness + `eval-corpus` answer key score Verdicts purely off the contract; grounding check resolves every `CitedSignal.signal_id` to a `TimelineEntry`; minor tag if touched. |
| **M5** | Freeze the **open wire** the paid fleet view rides on (D-0010): the open `Verdict` + a small open **aggregation envelope** in proto, so the closed controlplane implements behind it while cli stays open/dumb. Confirm D-0011 `CollectDirective` round-trip fields are complete for the adaptive multi-round loop. | controlplane returns `Verdict` (+ envelope) over the open contract; agent↔controlplane HTTPS uses only `gpufleet.v1`; license logic stays server-side (never in proto/cli); minor tag. |
| **M6** | Contract hardening from partner validation; promote to **`v1.0.0`** once the open wire is proven end-to-end on a real fleet. | `v1.0.0` tag cut; no breaking change introduced (any breaking need is deferred to a `gpufleet.v2` package, side-by-side); CONTRACTS registry updated. |

## Cross-cutting invariants (every milestone)

- **Additive-only within `v1`.** Removing/renumbering/retyping = breaking →
  `gpufleet.v2`, never an in-place `v1` edit.
- **Schema encodes the red lines**, not prose: evidence-in/verdict-out,
  ABSTAIN-as-zero, narration-only, declarative directives (no code), public XID
  + raw text only.
- **One gate schema** (`SignalSource`/`FaultClass`/`CitedSignal`) shared
  open `rca` ↔ closed controlplane; one PluginProto capability contract (D-0011).
- **Tags immutable; gen not committed; closed `api/` proto stays separate.**
