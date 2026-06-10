# gpufleet/proto

The **contract backbone** for gpufleet. This repository holds the versioned,
language-neutral API/ABI contracts (protobuf, managed by [buf](https://buf.build))
that every other module communicates through.

> This is an **OPEN** module (Apache-2.0). It is consumed as a **read-only,
> fixed-tag dependency**. Module repos NEVER edit these contracts directly — a
> contract change is a *contract-change-proposal* PR reviewed by the
> orchestrator. See [`CONTRACTS.md`](./CONTRACTS.md).

## What's here

| File | Contract |
| --- | --- |
| `schema/gpufleet/v1/signal.proto` | `EvidencePack` — the normalized, read-only window of signals (DCGM fields, XID/dmesg, NCCL, device↔job mapping, timeline). The only payload the open agent sends to the closed controlplane. |
| `schema/gpufleet/v1/verdict.proto` | `Verdict` — `{fault_class incl. ABSTAIN, confidence, cited_signals[], narration, cost_impact}`. The only payload the controlplane returns. |
| `schema/gpufleet/v1/plugin.proto` | `PluginService` — the open probe/tool protocol for adding a read-only evidence probe. |

## Boundary invariants encoded here

- **Evidence in, Verdict out.** The agent→controlplane call carries an
  `EvidencePack` (facts + provenance only — never prompts, playbooks,
  thresholds, or heuristics). The response is a `Verdict`.
- **ABSTAIN-by-default.** `FaultClass.FAULT_CLASS_UNSPECIFIED` (=0) is the safe,
  non-committal zero value; `FAULT_CLASS_ABSTAIN` (=1) is an explicit decline.
  A non-abstain `Verdict` MUST cite ≥2 `CitedSignal`s with **distinct**
  `SignalSource`s (the independence gate). This proto makes that representable
  and auditable; the gate itself lives in the closed engine.
- **Narration narrates.** `Verdict.narration` is LLM prose and is never the
  source of truth for `fault_class` / `confidence` / `cited_signals`.
- **No externally-sourced semantics.** Only publicly documented XID numbers and
  verbatim raw text are carried; no proprietary error-code meanings.

## Quick start

```bash
buf lint
buf format --diff          # check formatting
buf breaking --against '.git#branch=main'
buf generate               # emits gen/go and gen/python (gitignored)
```

`buf generate` produces Go (`gen/go`) and Python (`gen/python`) stubs using
remote plugins; generated code is **not** committed (see `.gitignore`).

## Versioning

Package is `gpufleet.v1`. Breaking changes require a new package version
(`gpufleet.v2`) running side-by-side. See [`CONTRACTS.md`](./CONTRACTS.md).

## License

Apache-2.0.
