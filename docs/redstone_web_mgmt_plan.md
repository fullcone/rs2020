# Redstone Web Management Plan

This is the management UI track for Redstone stage-1 and follow-up BCM work.
It starts with read-only status, recent evidence browsing, and safe evidence
actions. SDK reset-risk and flash actions are not ready to expose through a
browser.

## Initial Scope

- Serve a static page from `/www/redstone/`.
- Serve status JSON through `/cgi-bin/redstone-status`.
- Serve recent evidence JSON through `/cgi-bin/redstone-evidence`.
- Serve safe run artifact details and downloads through `/cgi-bin/redstone-artifact`.
- Serve the capture-only action through `/cgi-bin/redstone-action?action=capture`.
- Serve non-strict validation capture through
  `/cgi-bin/redstone-action?action=validate-capture`.
- Serve bench capture-only evidence through
  `/cgi-bin/redstone-action?action=bench-capture`.
- Start the web UI only when an operator runs `redstone-mgmt-web`.
- Bind to `127.0.0.1:8080` by default.
- Reuse `redstone-mgmt-status` for status and `redstone-mgmt-evidence` for
  recent run lists.
- Reuse `redstone-mgmt-artifact` for fixed-run file details, direct file lists,
  and downloads.
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

`redstone-mgmt-evidence` reports recent capture, validation, bench, and web
action runs from the configured Redstone evidence directories. It returns only
fixed-directory indexes and log excerpts; it does not accept arbitrary path
inputs.

`redstone-mgmt-artifact` reports or downloads files only from these fixed run
directories:

- capture runs below `/var/log/redstone-stage1/<run>`,
- validation runs below `/var/log/redstone-stage1/validate-*`,
- bench runs below `/var/log/redstone-stage1/bench-run-*`,
- web action runs below `/var/log/redstone-stage1/web-actions/<run>`.

For development builds, it intentionally allows any direct file with a safe
basename inside one of those run directories, plus the known run tarball sidecar
where present. `file=_files` lists direct files in the selected run directory
so operators can expose new diagnostic captures in the browser without changing
the UI first. It still rejects slash, backslash, dot-dot, hidden-name, and
non-token selectors.

## Safety Boundary

The first web slice must not:

- start automatically at boot,
- bind to an external address by default,
- run `redstone-openbcm-init-probe --exec`,
- accept the `i-accept-hardware-reset-risk` path from the browser,
- write U-Boot environment variables,
- write NAND, flash, or ONIE install targets.

## Next Web Actions

The explicit CGI actions are synchronous, protected by a single-action
directory lock, and write `result.env`, `result.json`, and `action.log` below
`/var/log/redstone-stage1/web-actions`.

Current actions:

1. `capture`: runs `redstone-stage1-capture --verbose`.
2. `validate-capture`: runs `redstone-stage1-validate --capture`.
3. `bench-capture`: runs `redstone-stage1-bench-run --capture-only`.

The browser polls status and evidence briefly after each action returns so the
latest action result, generated evidence, and log tail converge without a manual
refresh.

Remaining explicit CGI actions should be added in this order:

1. strict validation run with explicit `swpN`, local CIDR, and peer IP,
2. OpenBCM BDE smoke run,
3. OpenBCM init-probe dry-run with a selected BCM config,
4. SDK exec path only after hardware reset-risk policy is reviewed again.

Each action should write an evidence directory and return the path in JSON.
