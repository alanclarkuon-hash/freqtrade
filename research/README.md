# Freqtrade research setup

This folder contains research notes, credential-free examples, and source scripts
used to prepare the separate crypto VMware VM. It contains no generated VM files,
SSH keys, installation seeds, exchange credentials, market data, or trading results.

## Current environment

The approved runtime is Docker inside the dedicated `Hermes-Crypto` VMware VM.
Ubuntu 24.04.5 LTS, Docker Engine 29.9.1, Docker Compose 5.6.0, and Freqtrade 2026.9
were installed and verified on 19 October 2026. Freqtrade's image is pinned by
digest. The VM's current Compose file is `/opt/freqtrade-research/compose.yaml`;
it disables container networking and publishes no ports. Installation checks
created an empty data volume and the official sample strategy. No market-data
downloads or backtests have run in that VM.

The VM was powered off with the `crypto-freqtrade-installed-2026-10-19` snapshot.
Private verification records, disks, seeds, and SSH access files remain outside
this repository. The existing Hermes VM and other projects are separate.

## Files and execution scope

- `ASSESSMENT.md`: research findings, official sources, and OKX demo limitations.
- `prepare-crypto-vm.ps1`: historical provisioning source; refuses an existing
  destination. Requires machine-specific paths and dependencies to be reviewed.
  It must not be rerun against the installed VM.
- `configure-crypto-foundation.sh` and `verify-crypto-foundation.py`: foundation
  setup and acceptance scripts from before Docker installation. Their checks
  deliberately require Docker and Freqtrade to be absent.
- `read-crypto-hostkey.py`: reads only a powered-off crypto VM's public SSH key;
  requires separately staged disk-reading dependencies.
- `crypto-vm-console.py`: temporary installer-console helper. That console was
  removed after installation; this is not a normal access method.
- `compose.yaml`, `ft.ps1`, and `inputs/okx-spot.json`: earlier Windows Docker
  walkthrough examples. `ft.ps1` targets Windows Docker Desktop, not the VMware
  guest. These are retained as historical research files and are not the approved
  runtime configuration. Do not use them to start a host-side research workload.

Committing these scripts does not authorize provisioning, changing firewall rules,
starting trading, downloading data, or running experiments. Review the next phase
before operating the installed environment.

## Sensitive configuration

Follow the repository-wide standing instructions in
[`AGENTS.md`](../AGENTS.md) for private profile storage, tracked examples, generated
VM files, and checks before committing or pushing. No secret profile is created
by these research files.
