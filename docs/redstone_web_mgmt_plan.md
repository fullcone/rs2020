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
- Serve strict front-panel validation through
  `/cgi-bin/redstone-action?action=validate-strict&iface=swpN&local_cidr=IP/PREFIX&peer=IP`.
- Serve OpenBCM BDE smoke through
  `/cgi-bin/redstone-action?action=bde-smoke`.
- Serve OpenBCM init-probe dry-run through
  `/cgi-bin/redstone-action?action=init-probe-dry-run&config=stage1`.
- Start the web UI by default on Redstone BusyBox-init development images
  through `S41redstone-mgmt-web`; operators can still run `redstone-mgmt-web`
  manually.
- Bind to `0.0.0.0:8080` by default in development builds.
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
- selected-vs-original config comparison for portmap counts and split mode,
- eth1 management-port link state,
- BCM56846 PCI presence and bound driver,
- BDE device nodes, module presence, device paths, and diagnostic summary,
- switchd process state, executable path/presence, pidfile state, and stop
  reason,
- OpenBCM BDE smoke and init-probe tool paths plus latest run summary,
- OpenBCM SDK demo init executable presence so a dry-run wrapper pass is not
  mistaken for a usable SDK init/switchd path,
- Runtime diagnostics that explain the current BDE, switchd, and OpenBCM gate
  blockers without requiring shell access,
- development/public profile and reset-risk execution policy,
- top-level current blocker derived from the ordered hardware gates,
- front-panel port tiles derived from the selected portmap and live `swpN`
  sysfs state,
- latest capture directory/archive, validation directory/bundle, and bench-run
  evidence directory,
- validation PASS/WARN/FAIL counts parsed from `validate.log`,
- bench-run `validate_exit`, `bde_smoke_exit`, validation bundle, and evidence
  path fields parsed from `bench-run.log`,
- OpenBCM init-probe dry-run status parsed from the latest validation or
  capture evidence,
- latest web-triggered capture action status, log path, and evidence directory,
- gate analysis for management Ethernet, BCM56846, BDE node/module readiness,
  strict validation, init-probe dry-run, and the still-pending direct-boot
  matrix,
- availability of capture, validation, BDE smoke, and init-probe tools.

`redstone-mgmt-evidence` reports recent capture, validation, bench, BDE smoke,
and web action runs from the configured Redstone evidence directories. It
returns only fixed-directory indexes and log excerpts; it does not accept
arbitrary path inputs.

`redstone-mgmt-artifact` reports or downloads files only from these fixed run
directories:

- capture runs below `/var/log/redstone-stage1/<run>`,
- validation runs below `/var/log/redstone-stage1/validate-*`,
- bench runs below `/var/log/redstone-stage1/bench-run-*`,
- BDE smoke runs below `/var/log/redstone-stage1/openbcm-bde-smoke-*`,
- web action runs below `/var/log/redstone-stage1/web-actions/<run>`.

For development builds, it intentionally allows any direct file with a safe
basename inside one of those run directories, plus the known run tarball sidecar
where present. `file=_files` lists direct files in the selected run directory
so operators can expose new diagnostic captures in the browser without changing
the UI first. It still rejects slash, backslash, dot-dot, hidden-name, and
non-token selectors.

## Safety Boundary

The development web slice must not:

- run `redstone-openbcm-init-probe --exec`,
- accept the `i-accept-hardware-reset-risk` path from the browser,
- write U-Boot environment variables,
- write NAND, flash, or ONIE install targets.

Public firmware still needs a separate lockdown profile before release. That
profile should revisit default binding, default boot enablement, and which
diagnostic files are visible through the browser.

## Next Web Actions

The explicit CGI actions are synchronous, protected by a single-action
directory lock, and write `result.env`, `result.json`, and `action.log` below
`/var/log/redstone-stage1/web-actions`.

Current actions:

1. `capture`: runs `redstone-stage1-capture --verbose`.
2. `validate-capture`: runs `redstone-stage1-validate --capture`.
3. `bench-capture`: runs `redstone-stage1-bench-run --capture-only`.
4. `validate-strict`: validates a selected `swpN` interface with an explicit
   local CIDR, peer IP, and ping count by calling `redstone-stage1-bench-run`.
5. `bde-smoke`: runs `redstone-openbcm-bde-smoke.sh --strict --capture` when
   the helper is available in `/opt/openbcm-bde/`, the current bundle
   directory, or `PATH`. Redstone rootfs and web/SSH hotfix packaging install
   a PATH helper at `/usr/sbin/redstone-openbcm-bde-smoke.sh`; when that helper
   is used, the action passes a concrete `--bundle-dir` so `/opt/openbcm-bde`
   remains usable for the module bundle. The OpenBCM BDE module build must keep
   `-fno-common` in the generated target and Kbuild flags; Linux 5.10 rejects
   the BDE module when a later standalone `-fcommon` flag reintroduces common
   symbols. The helper and `platform-init.sh` create the legacy static
   `/dev/linux-kernel-bde` and `/dev/linux-user-bde` character nodes from
   `/proc/devices` because these BDE modules do not create devtmpfs nodes by
   themselves.
6. `init-probe-dry-run`: runs `redstone-openbcm-init-probe --dry-run` with a
   selected BCM config token. The browser exposes only known config tokens, not
   arbitrary paths. The probe binary is statically linked for the uClibc
   stage-1 rootfs. `redstone-mgmt-status` treats the latest Web action log as
   init-probe evidence, because this dry-run verifies BDE nodes, exact BCM56846
   PCI presence, and config readability without creating a separate evidence
   directory. A successful dry-run does not prove the SDK demo init or switchd
   datapath; the current hardware blocker is still the missing executable SDK
   init/switchd path.

The browser polls status and evidence briefly after each action returns so the
latest action result, generated evidence, and log tail converge without a manual
refresh.

Remaining explicit CGI actions should be added in this order:

1. Switchd/OpenBCM management status for the executable SDK init path, including
   the exact missing binary/config blocker when the BDE and dry-run gates pass.
2. SDK exec path only after hardware reset-risk policy is reviewed again.
3. Public-firmware lockdown profile that disables development diagnostics not
   intended for field images.

Each action should write an evidence directory and return the path in JSON.
