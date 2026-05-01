# Redstone Web Management Plan

This is the management UI track for Redstone stage-1 and follow-up BCM work.
It starts with status plus one safe evidence action: the current image can prove
management Ethernet and collect evidence, but SDK reset-risk and flash actions
are not ready to expose through a browser.

## Initial Scope

- Serve a static page from `/www/redstone/`.
- Serve status JSON through `/cgi-bin/redstone-status`.
- Serve the capture-only action through `/cgi-bin/redstone-action?action=capture`.
- Start the web UI only when an operator runs `redstone-mgmt-web`.
- Bind to `127.0.0.1:8080` by default.
- Reuse `redstone-mgmt-status` as the single data source for the page, capture
  tool, and later action endpoints.
- Store web action logs under `/var/log/redstone-stage1/web-actions`.

## Current Status Fields

`redstone-mgmt-status` reports:

- selected board profile,
- selected BCM config path, SHA256, portmap count, and detected split mode,
- original SDK reference manifest presence plus generated config/PHY hashes,
- eth1 management-port link state,
- BCM56846 PCI presence and bound driver,
- BDE device nodes and module presence,
- switchd process state,
- latest capture directory/archive, validation directory/bundle, and bench-run
  evidence directory,
- validation PASS/WARN/FAIL counts parsed from `validate.log`,
- bench-run `validate_exit`, `bde_smoke_exit`, validation bundle, and evidence
  path fields parsed from `bench-run.log`,
- OpenBCM init-probe dry-run status parsed from the latest validation or
  capture evidence,
- latest web-triggered capture action status, log path, and evidence directory,
- availability of capture, validation, BDE smoke, and init-probe tools.

## Safety Boundary

The first web slice must not:

- start automatically at boot,
- bind to an external address by default,
- run `redstone-openbcm-init-probe --exec`,
- accept the `i-accept-hardware-reset-risk` path from the browser,
- write U-Boot environment variables,
- write NAND, flash, or ONIE install targets.

## Next Web Actions

The first explicit CGI action is now the capture-only evidence run. It is
synchronous, protected by a single-action directory lock, and writes
`result.env`, `result.json`, and `action.log` below
`/var/log/redstone-stage1/web-actions`.

Remaining explicit CGI actions should be added in this order:

1. strict validation run with explicit `swpN`, local CIDR, and peer IP,
2. OpenBCM BDE smoke run,
3. OpenBCM init-probe dry-run with a selected BCM config,
4. SDK exec path only after hardware reset-risk policy is reviewed again.

Each action should write an evidence directory and return the path in JSON.
