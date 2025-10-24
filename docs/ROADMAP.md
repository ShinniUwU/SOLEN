# SOLEN Roadmap

1. Standardize flags, exit codes, and JSON across all scripts.
2. Inventory v1 with <1s runtime, no root, graceful degradation.
3. Package abstraction for apt + dnf: `check`, `update`, `upgrade`, `autoremove`.
4. Services management: `status`, `ensure-enabled`, `ensure-running`, `restart-if-failed`.
5. Backups v1: YAML profiles, dry-run listing, retention pruning.
6. Health v1: fast checks with actionable summary and non-zero on failure.
7. Observability hooks: configurable webhooks; NDJSON stream as primary output.
8. Governance: policy file; refuse dangerous ops with exit code 4.
9. Quality gates: golden fixtures and smoke tests in containers.

