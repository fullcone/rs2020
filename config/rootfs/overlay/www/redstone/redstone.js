const statusUrl = "/cgi-bin/redstone-status";
const evidenceUrl = "/cgi-bin/redstone-evidence";
const actionUrl = "/cgi-bin/redstone-action";
const artifactUrl = "/cgi-bin/redstone-artifact";

let actionPollTimer = null;

const text = (id, value) => {
  const node = document.getElementById(id);
  if (node) node.textContent = value || "unknown";
};

const stateClass = (id, state) => {
  const node = document.getElementById(id);
  if (!node) return;
  node.classList.remove("ok", "warn", "bad");
  if (state) node.classList.add(state);
};

const yesNo = (value) => (value ? "yes" : "no");
const pathOrNone = (value) => value || "none";
const exitLabel = (value) => (value === undefined || value === "" ? "not run" : `exit ${value}`);
const boolLabel = (value) => {
  if (value === true || value === "true") return "yes";
  if (value === false || value === "false") return "no";
  return value || "unknown";
};

const bytesLabel = (value) => {
  const bytes = Number(value || 0);
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KiB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MiB`;
};

const linkLabel = (eth) => {
  if (!eth || !eth.present) return "missing";
  if (eth.carrier === "1") return `${eth.speed || "unknown"} ${eth.duplex || ""}`.trim();
  return eth.operstate || "down";
};

const validationLabel = (summary) => {
  if (!summary || !summary.log) return "none";
  if (!summary.log_exists) return "missing log";
  const pass = Number(summary.pass_count || 0);
  const warn = Number(summary.warn_count || 0);
  const fail = Number(summary.fail_count || 0);
  return `${pass} pass, ${warn} warn, ${fail} fail`;
};

const validationState = (summary) => {
  if (!summary || !summary.log_exists) return "warn";
  if (Number(summary.fail_count || 0) > 0) return "bad";
  if (Number(summary.warn_count || 0) > 0) return "warn";

  const hasResults =
    Number(summary.pass_count || 0) > 0 ||
    Number(summary.warn_count || 0) > 0 ||
    Number(summary.fail_count || 0) > 0;
  return hasResults || summary.complete ? "ok" : "warn";
};

const probeLabel = (probe) => {
  if (!probe || !probe.exists) return "not run";
  if (probe.unavailable) return "tool unavailable";
  return exitLabel(probe.exit);
};

const actionLabel = (action) => {
  if (!action || !action.status) return "none";
  const name = action.action || "action";
  const exit = action.exit === undefined || action.exit === "" ? "" : ` (${exitLabel(action.exit)})`;
  return `${name} ${action.status}${exit}`;
};

const actionState = (action) => {
  if (!action || !action.status) return "warn";
  if (action.status === "success") return "ok";
  if (action.status === "failed" || action.status === "rejected") return "bad";
  return "warn";
};

const benchState = (run) => {
  if (!run || run.validate_exit === "") return "warn";
  return run.validate_exit === "0" ? "ok" : "bad";
};

const gateLabel = (value) => (value ? "ready" : "pending");
const inputValue = (id) => {
  const node = document.getElementById(id);
  return node ? node.value.trim() : "";
};

const artifactRequest = (kind, run, file, download = false) =>
  `${artifactUrl}?kind=${encodeURIComponent(kind)}&run=${encodeURIComponent(run)}&file=${encodeURIComponent(file)}${download ? "&download=1" : ""}`;

async function fetchJson(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`${url} ${response.status}`);
  return response.json();
}

function runRow({ title, state, lines, tail, actions }) {
  const row = document.createElement("div");
  row.className = "run-row";
  if (state) row.classList.add(state);

  const heading = document.createElement("strong");
  heading.textContent = title || "unknown";
  row.appendChild(heading);

  (lines || []).filter(Boolean).forEach((line) => {
    const item = document.createElement("span");
    item.textContent = line;
    row.appendChild(item);
  });

  if (tail) {
    const pre = document.createElement("pre");
    pre.className = "run-tail";
    pre.textContent = tail;
    row.appendChild(pre);
  }

  if (actions && actions.length) {
    const actionRow = document.createElement("div");
    actionRow.className = "run-actions";
    actions.forEach((action) => {
      if (action.href) {
        const link = document.createElement("a");
        link.className = "button-link compact";
        link.href = action.href;
        link.textContent = action.label;
        actionRow.appendChild(link);
        return;
      }

      const button = document.createElement("button");
      button.type = "button";
      button.className = "compact";
      button.textContent = action.label;
      button.addEventListener("click", action.onClick);
      actionRow.appendChild(button);
    });
    row.appendChild(actionRow);
  }

  return row;
}

function renderRuns(id, runs, mapper) {
  const node = document.getElementById(id);
  if (!node) return;
  node.textContent = "";

  if (!runs || runs.length === 0) {
    node.appendChild(runRow({ title: "none", state: "warn" }));
    return;
  }

  runs.forEach((run) => node.appendChild(runRow(mapper(run))));
}

function renderEvidence(evidence) {
  renderRuns("capture-runs", evidence.capture_runs, (run) => ({
    title: run.name,
    state: run.summary_exists ? "ok" : "warn",
    lines: [
      `summary ${run.summary_exists ? "present" : "missing"}`,
      `archive ${run.archive_exists ? "present" : "missing"}`,
      run.path,
    ],
    tail: run.summary_head,
    actions: [
      { label: "Files", onClick: () => showArtifact("capture", run.name, "_files") },
      { label: "Summary", onClick: () => showArtifact("capture", run.name, "capture-summary.txt") },
      ...(run.archive_exists ? [{ label: "Archive", href: artifactRequest("capture", run.name, "archive", true) }] : []),
    ],
  }));

  renderRuns("validation-runs", evidence.validation_runs, (run) => ({
    title: run.name,
    state: validationState(run),
    lines: [
      validationLabel(run),
      `bundle ${run.bundle_exists ? "present" : "missing"}`,
      run.path,
    ],
    tail: run.log_tail,
    actions: [
      { label: "Files", onClick: () => showArtifact("validation", run.name, "_files") },
      { label: "Log", onClick: () => showArtifact("validation", run.name, "validate.log") },
      { label: "Probe", onClick: () => showArtifact("validation", run.name, "openbcm_init_probe_dry_run.txt") },
      ...(run.bundle_exists ? [{ label: "Bundle", href: artifactRequest("validation", run.name, "archive", true) }] : []),
    ],
  }));

  renderRuns("bench-runs", evidence.bench_runs, (run) => ({
    title: run.name,
    state: benchState(run),
    lines: [
      `validate ${exitLabel(run.validate_exit)}`,
      `bde ${exitLabel(run.bde_smoke_exit)}`,
      run.path,
    ],
    tail: run.log_tail,
    actions: [
      { label: "Files", onClick: () => showArtifact("bench", run.name, "_files") },
      { label: "Log", onClick: () => showArtifact("bench", run.name, "bench-run.log") },
      { label: "Validator", onClick: () => showArtifact("bench", run.name, "validate-console.log") },
    ],
  }));

  renderRuns("action-runs", evidence.web_actions, (run) => ({
    title: run.name,
    state: actionState(run),
    lines: [
      actionLabel(run),
      pathOrNone(run.evidence_dir),
      pathOrNone(run.log),
    ],
    tail: run.log_tail,
    actions: [
      { label: "Files", onClick: () => showArtifact("action", run.name, "_files") },
      { label: "Log", onClick: () => showArtifact("action", run.name, "action.log") },
      { label: "Result", onClick: () => showArtifact("action", run.name, "result.env") },
      { label: "Download", href: artifactRequest("action", run.name, "action.log", true) },
    ],
  }));
}

function renderFrontPanel(frontPanel) {
  const panel = frontPanel || {};
  const ports = Array.isArray(panel.ports) ? panel.ports : [];
  text("front-panel-configured", String(panel.configured_count || 0));
  text("front-panel-present", String(panel.swp_present_count || 0));
  text("front-panel-link-up", String(panel.swp_link_up_count || 0));
  text("front-panel-source", panel.source_config || "unknown");

  const node = document.getElementById("front-panel-ports");
  if (!node) return;
  node.textContent = "";

  if (ports.length === 0) {
    const empty = document.createElement("div");
    empty.className = "port-tile missing";
    empty.textContent = "No portmap entries";
    node.appendChild(empty);
    return;
  }

  ports.forEach((port) => {
    const tile = document.createElement("div");
    tile.className = "port-tile";
    if (port.carrier === "1") tile.classList.add("link-up");
    if (!port.present) tile.classList.add("missing");

    const title = document.createElement("strong");
    title.textContent = port.name || `swp${port.port || "?"}`;
    tile.appendChild(title);

    const lane = document.createElement("span");
    lane.textContent = `lane ${port.lane || "?"}, ${port.speed || "?"}G`;
    tile.appendChild(lane);

    const state = document.createElement("span");
    state.textContent = port.present ? `${port.operstate || "unknown"} carrier=${port.carrier || "unknown"}` : "missing";
    tile.appendChild(state);

    node.appendChild(tile);
  });
}

function renderStatus(data) {
  const cfg = data.selected_config || {};
  const profile = data.profile || {};
  const eth = data.management_eth1 || {};
  const frontPanel = data.front_panel || {};
  const bcm = data.bcm56846 || {};
  const bde = data.bde || {};
  const sw = data.switchd || {};
  const openbcm = data.openbcm || {};
  const sdk = data.original_sdk_reference || {};
  const evidence = data.evidence || {};
  const captureSummary = evidence.latest_capture_summary || {};
  const validation = evidence.validation_summary || {};
  const bench = evidence.bench_summary || {};
  const probe = evidence.init_probe_dry_run || {};
  const webAction = data.web_action || {};
  const tools = data.tools || {};
  const diagnostics = data.diagnostics || {};
  const analysis = data.analysis || {};
  const bdeReady = Object.prototype.hasOwnProperty.call(analysis, "bde_ready")
    ? analysis.bde_ready
    : analysis.bde_nodes_ready;

  text("board", data.board);
  text("split-mode", cfg.split_mode);
  text("mgmt-link", linkLabel(eth));
  text("bcm-state", bcm.pci_present ? "present" : "missing");
  text("eth-address", eth.address);
  text("eth-state", `${eth.operstate || "unknown"} carrier=${eth.carrier || "unknown"}`);
  text("eth-speed", `${eth.speed || "unknown"} ${eth.duplex || ""}`.trim());
  text("bcm-slot", bcm.slot || "missing");
  text("bcm-driver", bcm.driver || "none");
  text("kernel-bde", `${yesNo(bde.kernel_node)} node, ${yesNo(bde.kernel_module)} module`);
  text("user-bde", `${yesNo(bde.user_node)} node, ${yesNo(bde.user_module)} module`);
  text("config-path", cfg.path);
  text("config-sha", cfg.sha256 || "unavailable");
  text("config-portmaps", String(cfg.portmap_count || 0));
  text("switchd", sw.running ? `running ${sw.pids || ""}`.trim() : "stopped");
  text("bde-diagnostic", diagnostics.bde || bde.summary || "unknown");
  text(
    "bde-paths",
    `${bde.kernel_node_path || "/dev/linux-kernel-bde"}=${yesNo(bde.kernel_node)} ${bde.user_node_path || "/dev/linux-user-bde"}=${yesNo(bde.user_node)}`,
  );
  text("switchd-diagnostic", diagnostics.switchd || sw.summary || "unknown");
  text(
    "switchd-pidfile",
    `${sw.pid_file || "/var/run/switchd.pid"} exists=${yesNo(sw.pid_file_exists)} pid=${sw.pid_file_pid || "none"} alive=${yesNo(sw.pid_file_running)}`,
  );
  text("openbcm-diagnostic", diagnostics.openbcm || openbcm.summary || "unknown");
  text(
    "openbcm-tools",
    `smoke=${pathOrNone(openbcm.bde_smoke_tool)} probe=${pathOrNone(openbcm.init_probe_tool)}`,
  );
  text("sdk-ref", sdk.exists ? `${sdk.generated_portmap_count || "unknown"} portmaps` : "missing");
  text("sdk-split", sdk.split_interfaces || "unknown");
  text("sdk-config-sha", sdk.generated_config_sha256 || "unavailable");
  text("sdk-phy-sha", sdk.generated_phy_sha256 || "unavailable");
  text("sdk-original-tuning", boolLabel(sdk.has_original_global_tuning));
  text("sdk-phy84848", boolLabel(sdk.has_phy_84848));
  text("sdk-fxe52", sdk.fxe52_unsplit === "true" ? "unsplit 40G" : boolLabel(sdk.fxe52_unsplit));
  text("latest-capture-dir", pathOrNone(evidence.latest_capture_dir));
  text("latest-capture-archive", pathOrNone(evidence.latest_capture_archive));
  text("latest-validate-dir", pathOrNone(evidence.latest_validate_dir));
  text("latest-validate-bundle", pathOrNone(evidence.latest_validate_bundle));
  text("latest-bench-dir", pathOrNone(evidence.latest_bench_dir));
  text("validation-summary", validationLabel(validation));
  text("validation-log", pathOrNone(validation.log));
  text("bench-validate-exit", exitLabel(bench.validate_exit));
  text("bde-smoke", exitLabel(bench.bde_smoke_exit));
  text("init-probe", probeLabel(probe));
  text("capture-summary", captureSummary.exists ? captureSummary.path : "none");
  text("action-state", actionLabel(webAction));
  text("latest-action", actionLabel(webAction));
  text("action-log", pathOrNone(webAction.log));
  text("action-evidence", pathOrNone(webAction.evidence_dir));
  text("action-message", pathOrNone(webAction.message));
  text("action-finished", pathOrNone(webAction.finished_at));
  text("generated-at", data.generated_at);
  text("mgmt-sgmii", eth.carrier === "1" ? "link proven" : "not proven");
  text("hardware-bcm", bcm.pci_present ? `${bcm.slot || "present"} ${bcm.driver || "no driver"}` : "missing");
  text("hardware-bde", `${yesNo(bde.kernel_node && bde.user_node)} nodes, ${yesNo(bde.kernel_module && bde.user_module)} modules`);
  text("hardware-probe", probeLabel(probe));
  text(
    "hardware-tools",
    `smoke=${yesNo(tools.redstone_openbcm_bde_smoke)} probe=${yesNo(tools.redstone_openbcm_init_probe)}`,
  );
  text("hardware-validation", validationLabel(validation));
  text("hardware-openbcm-gate", `BDE ${exitLabel(bench.bde_smoke_exit)}, probe ${probeLabel(probe)}`);
  text("direct-boot-gate", eth.carrier === "1" ? "U-Boot-preserved SGMII proven; direct boot still pending" : "manual SerDes evidence required");
  text("profile-mode", profile.mode || "unknown");
  text("reset-risk-exec", profile.reset_risk_exec ? "enabled" : "disabled");
  text("analysis-management", gateLabel(analysis.management_eth_ready));
  text("analysis-bcm", gateLabel(analysis.bcm56846_ready));
  text("analysis-bde", gateLabel(bdeReady));
  text("analysis-strict", gateLabel(analysis.strict_validation_ready));
  text("analysis-probe", gateLabel(analysis.openbcm_probe_ready));
  text("analysis-direct-boot", analysis.direct_boot_matrix || "pending");
  renderFrontPanel(frontPanel);

  stateClass("mgmt-link", eth.carrier === "1" ? "ok" : "bad");
  stateClass("bcm-state", bcm.pci_present ? "ok" : "bad");
  stateClass("switchd", sw.running ? "ok" : "warn");
  stateClass("bde-diagnostic", bdeReady ? "ok" : "warn");
  stateClass("bde-paths", bdeReady ? "ok" : "warn");
  stateClass("switchd-diagnostic", sw.running ? "ok" : "warn");
  stateClass("switchd-pidfile", sw.pid_file_running ? "ok" : sw.pid_file_exists ? "warn" : "warn");
  stateClass("openbcm-diagnostic", analysis.openbcm_probe_ready ? "ok" : "warn");
  stateClass("openbcm-tools", openbcm.bde_smoke_tool && openbcm.init_probe_tool ? "ok" : "warn");
  stateClass("sdk-ref", sdk.exists ? "ok" : "warn");
  stateClass("validation-summary", validationState(validation));
  stateClass("bench-validate-exit", bench.validate_exit === "0" ? "ok" : bench.validate_exit ? "bad" : "warn");
  stateClass("bde-smoke", bench.bde_smoke_exit === "0" ? "ok" : bench.bde_smoke_exit ? "bad" : "warn");
  stateClass("init-probe", probe.exists && probe.exit === "0" && !probe.unavailable ? "ok" : probe.exists ? "warn" : "warn");
  stateClass("action-state", actionState(webAction));
  stateClass("latest-action", actionState(webAction));
  stateClass("mgmt-sgmii", eth.carrier === "1" ? "ok" : "warn");
  stateClass("hardware-bcm", bcm.pci_present ? "ok" : "bad");
  stateClass("hardware-bde", bdeReady ? "ok" : "warn");
  stateClass("hardware-probe", probe.exists && probe.exit === "0" && !probe.unavailable ? "ok" : "warn");
  stateClass("hardware-tools", tools.redstone_openbcm_bde_smoke && tools.redstone_openbcm_init_probe ? "ok" : "warn");
  stateClass("hardware-validation", validationState(validation));
  stateClass("hardware-openbcm-gate", bench.bde_smoke_exit === "0" && probe.exists && probe.exit === "0" ? "ok" : "warn");
  stateClass("direct-boot-gate", "warn");
  stateClass("reset-risk-exec", profile.reset_risk_exec ? "bad" : "ok");
  stateClass("analysis-management", analysis.management_eth_ready ? "ok" : "warn");
  stateClass("analysis-bcm", analysis.bcm56846_ready ? "ok" : "warn");
  stateClass("analysis-bde", bdeReady ? "ok" : "warn");
  stateClass("analysis-strict", analysis.strict_validation_ready ? "ok" : "warn");
  stateClass("analysis-probe", analysis.openbcm_probe_ready ? "ok" : "warn");
  stateClass("analysis-direct-boot", "warn");
  stateClass("front-panel-link-up", Number(frontPanel.swp_link_up_count || 0) > 0 ? "ok" : "warn");
}

async function showArtifact(kind, run, file) {
  text("artifact-kind", kind);
  text("artifact-run", run);
  text("artifact-file", file);
  text("artifact-status", "loading");
  text("artifact-size", "unknown");
  text("artifact-path", "unknown");
  text("artifact-tail", "Loading artifact...");
  stateClass("artifact-status", "warn");

  const download = document.getElementById("artifact-download");
  if (download) {
    download.classList.add("disabled");
    download.setAttribute("aria-disabled", "true");
    download.setAttribute("href", "#");
  }

  try {
    const artifact = await fetchJson(artifactRequest(kind, run, file));
    text("artifact-status", artifact.status || "unknown");
    text("artifact-size", bytesLabel(artifact.size));
    text("artifact-path", artifact.path || "none");
    text("artifact-tail", artifact.tail || (artifact.files || []).join("\n") || artifact.message || "No content.");
    stateClass("artifact-status", artifact.status === "ok" ? "ok" : "bad");

    if (download && artifact.download_url && artifact.status === "ok") {
      download.href = artifact.download_url;
      download.classList.remove("disabled");
      download.removeAttribute("aria-disabled");
    }
  } catch (error) {
    text("artifact-status", `error: ${error.message}`);
    text("artifact-tail", `Artifact unavailable: ${error.message}`);
    stateClass("artifact-status", "bad");
  }
}

async function refreshEvidence() {
  const evidence = await fetchJson(evidenceUrl);
  renderEvidence(evidence);
}

async function refresh() {
  const data = await fetchJson(statusUrl);
  renderStatus(data);
  await refreshEvidence();
}

function startActionPolling() {
  if (actionPollTimer) clearInterval(actionPollTimer);
  const stopAt = Date.now() + 30000;
  actionPollTimer = setInterval(() => {
    refresh().catch((error) => {
      text("generated-at", `status unavailable: ${error.message}`);
      stateClass("generated-at", "bad");
    });
    if (Date.now() > stopAt) {
      clearInterval(actionPollTimer);
      actionPollTimer = null;
    }
  }, 2500);
}

function setActionButtons(disabled) {
  document.querySelectorAll("[data-action]").forEach((button) => {
    button.disabled = disabled;
  });
}

function actionParams(action) {
  const params = new URLSearchParams({ action });
  if (action === "validate-strict") {
    params.set("iface", inputValue("strict-iface"));
    params.set("local_cidr", inputValue("strict-local-cidr"));
    params.set("peer", inputValue("strict-peer"));
    params.set("ping_count", inputValue("strict-ping-count") || "3");
  } else if (action === "init-probe-dry-run") {
    params.set("config", inputValue("init-probe-config") || "stage1");
  }
  return params.toString();
}

async function runAction(action) {
  setActionButtons(true);
  text("action-state", `${action} running`);
  stateClass("action-state", "warn");

  try {
    const response = await fetch(`${actionUrl}?${actionParams(action)}`, {
      method: "POST",
      cache: "no-store",
    });
    const result = await response.json();
    if (!response.ok) throw new Error(`action ${response.status}`);

    text("action-state", actionLabel(result));
    text("latest-action", actionLabel(result));
    text("action-log", pathOrNone(result.log));
    text("action-evidence", pathOrNone(result.evidence_dir));
    text("action-message", pathOrNone(result.message));
    text("action-finished", pathOrNone(result.finished_at));
    stateClass("action-state", actionState(result));
    stateClass("latest-action", actionState(result));
    await refresh();
    startActionPolling();
  } catch (error) {
    text("action-state", `action failed: ${error.message}`);
    stateClass("action-state", "bad");
  } finally {
    setActionButtons(false);
  }
}

document.querySelectorAll("[data-action]").forEach((button) => {
  button.addEventListener("click", () => runAction(button.dataset.action));
});

document.querySelectorAll(".tab").forEach((button) => {
  button.addEventListener("click", () => {
    const target = button.dataset.view;
    document.querySelectorAll(".tab").forEach((tab) => tab.classList.toggle("active", tab === button));
    document.querySelectorAll(".view").forEach((view) => {
      view.classList.toggle("active", view.id === `view-${target}`);
    });
  });
});

document.getElementById("refresh").addEventListener("click", () => {
  refresh().catch((error) => {
    text("generated-at", `status unavailable: ${error.message}`);
    stateClass("generated-at", "bad");
  });
});

document.getElementById("refresh-evidence").addEventListener("click", () => {
  refreshEvidence().catch((error) => {
    text("generated-at", `evidence unavailable: ${error.message}`);
    stateClass("generated-at", "bad");
  });
});

refresh().catch((error) => {
  text("generated-at", `status unavailable: ${error.message}`);
  stateClass("generated-at", "bad");
});
