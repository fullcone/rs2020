const statusUrl = "/cgi-bin/redstone-status";
const evidenceUrl = "/cgi-bin/redstone-evidence";
const actionUrl = "/cgi-bin/redstone-action";

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

async function fetchJson(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`${url} ${response.status}`);
  return response.json();
}

function runRow({ title, state, lines, tail }) {
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
  }));
}

function renderStatus(data) {
  const cfg = data.selected_config || {};
  const eth = data.management_eth1 || {};
  const bcm = data.bcm56846 || {};
  const bde = data.bde || {};
  const sw = data.switchd || {};
  const sdk = data.original_sdk_reference || {};
  const evidence = data.evidence || {};
  const captureSummary = evidence.latest_capture_summary || {};
  const validation = evidence.validation_summary || {};
  const bench = evidence.bench_summary || {};
  const probe = evidence.init_probe_dry_run || {};
  const webAction = data.web_action || {};

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
  text("sdk-ref", sdk.exists ? `${sdk.generated_portmap_count || "unknown"} portmaps` : "missing");
  text("sdk-split", sdk.split_interfaces || "unknown");
  text("sdk-config-sha", sdk.generated_config_sha256 || "unavailable");
  text("sdk-phy-sha", sdk.generated_phy_sha256 || "unavailable");
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
  text("hardware-bde", `${yesNo(bde.kernel_node && bde.user_node)} nodes`);
  text("hardware-probe", probeLabel(probe));

  stateClass("mgmt-link", eth.carrier === "1" ? "ok" : "bad");
  stateClass("bcm-state", bcm.pci_present ? "ok" : "bad");
  stateClass("switchd", sw.running ? "ok" : "warn");
  stateClass("sdk-ref", sdk.exists ? "ok" : "warn");
  stateClass("validation-summary", validationState(validation));
  stateClass("bench-validate-exit", bench.validate_exit === "0" ? "ok" : bench.validate_exit ? "bad" : "warn");
  stateClass("bde-smoke", bench.bde_smoke_exit === "0" ? "ok" : bench.bde_smoke_exit ? "bad" : "warn");
  stateClass("init-probe", probe.exists && probe.exit === "0" && !probe.unavailable ? "ok" : probe.exists ? "warn" : "warn");
  stateClass("action-state", actionState(webAction));
  stateClass("latest-action", actionState(webAction));
  stateClass("mgmt-sgmii", eth.carrier === "1" ? "ok" : "warn");
  stateClass("hardware-bcm", bcm.pci_present ? "ok" : "bad");
  stateClass("hardware-bde", bde.kernel_node && bde.user_node ? "ok" : "warn");
  stateClass("hardware-probe", probe.exists && probe.exit === "0" && !probe.unavailable ? "ok" : "warn");
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

function setActionButtons(disabled) {
  document.querySelectorAll("[data-action]").forEach((button) => {
    button.disabled = disabled;
  });
}

async function runAction(action) {
  setActionButtons(true);
  text("action-state", `${action} running`);
  stateClass("action-state", "warn");

  try {
    const response = await fetch(`${actionUrl}?action=${encodeURIComponent(action)}`, {
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
