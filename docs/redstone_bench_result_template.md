# Redstone Stage-1 Bench Result

This note is filled out for each Redstone hardware run and kept beside the
returned validation bundle. Stage-1 acceptance requires a strict validation
bundle and passing host analysis; capture-only inventory is not acceptance.

## Run Metadata

- Run ID:
- Operator:
- Bench date UTC:
- Redstone unit identifier:
- Handoff package:
- Handoff git head:
- Installer image:
- Console log path:

## Network Setup

- Front-panel interface:
- Local CIDR:
- Peer IP:
- Peer device and port:
- Cable or optic:
- Peer speed and duplex:
- Expected VLAN or L2 mode:

## Commands Run

- ONIE install command:
- Capture-only command: `redstone-stage1-bench-run --capture-only`
- Strict acceptance command:
- Optional BDE smoke command:
- Init probe dry-run command:
- Init probe exec command: not run / run with reset-risk approval

## Returned Artifacts

- Capture-only bundle or directory:
- Strict validation bundle or directory:
- Handoff/capture analysis output:
- BDE smoke capture bundle or directory:
- Console log:
- Photos or label notes:

## Results

- Booted to shell: yes/no
- `/etc/edgenos/board` is `redstone`: yes/no
- BCM56846 exact PCI ID `14e4:b846`: yes/no
- BDE modules loaded: yes/no
- `/dev/linux-bcm-*` or `/dev/linux-*-bde` nodes present: yes/no
- `switchd` started with `redstone-stage1.bcm`: yes/no
- `swp` interface present: yes/no
- Selected `swpN` link up: yes/no
- Ping through front-panel port: yes/no
- Host analysis passed strict: yes/no
- Stage-1 accepted: yes/no

## Observations

- Kernel or driver warnings:
- switchd or BDE warnings:
- Link or PHY observations:
- Reset events:
- Follow-up changes needed:
