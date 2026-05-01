# Redstone Web Management Plan

This is the management UI track for Redstone stage-1 and follow-up BCM work.
It is intentionally read-only at first: the current image can prove management
Ethernet and collect evidence, but SDK reset-risk and flash actions are not
ready to expose through a browser.

## Initial Scope

- Serve a static page from `/www/redstone/`.
- Serve status JSON through `/cgi-bin/redstone-status`.
- Start the web UI only when an operator runs `redstone-mgmt-web`.
- Bind to `127.0.0.1:8080` by default.
- Reuse `redstone-mgmt-status` as the single data source for the page, capture
  tool, and later action endpoints.

## Current Status Fields

`redstone-mgmt-status` reports:

- selected board profile,
- selected BCM config path, SHA256, portmap count, and detected split mode,
- eth1 management-port link state,
- BCM56846 PCI presence and bound driver,
- BDE device nodes and module presence,
- switchd process state,
- latest capture and bench evidence paths,
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

After the read-only page is verified on hardware, add explicit CGI actions in
this order:

1. capture-only evidence run,
2. strict validation run with explicit `swpN`, local CIDR, and peer IP,
3. OpenBCM BDE smoke run,
4. OpenBCM init-probe dry-run with a selected BCM config,
5. SDK exec path only after hardware reset-risk policy is reviewed again.

Each action should write an evidence directory and return the path in JSON.
