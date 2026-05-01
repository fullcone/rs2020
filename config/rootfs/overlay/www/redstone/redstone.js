const statusUrl = "/cgi-bin/redstone-status";
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
  const pass = Number(summary.pass_count || 0);
  const warn = Number(summary.warn_count || 0);
  const fail = Number(summary.fail_count || 0);
  return `${pass} pass, ${warn} warn, ${fail} fail`;
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

async function refresh() {
  const response = await fetch(statusUrl, { cache: "no-store" });
  if (!response.ok) throw new Error(`status ${response.status}`);
  const data = await response.json();

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

  stateClass("mgmt-link", eth.carrier === "1" ? "ok" : "bad");
  stateClass("bcm-state", bcm.pci_present ? "ok" : "bad");
  stateClass("switchd", sw.running ? "ok" : "warn");
  stateClass("sdk-ref", sdk.exists ? "ok" : "warn");
  stateClass("validation-summary", validation.fail_count > 0 ? "bad" : validation.warn_count > 0 ? "warn" : validation.log ? "ok" : "warn");
  stateClass("bench-validate-exit", bench.validate_exit === "0" ? "ok" : bench.validate_exit ? "bad" : "warn");
  stateClass("bde-smoke", bench.bde_smoke_exit === "0" ? "ok" : bench.bde_smoke_exit ? "bad" : "warn");
  stateClass("init-probe", probe.exists && probe.exit === "0" && !probe.unavailable ? "ok" : probe.exists ? "warn" : "warn");
  stateClass("action-state", actionState(webAction));
  stateClass("latest-action", actionState(webAction));
}

const runCapture = document.getElementById("run-capture");
if (runCapture) {
  runCapture.addEventListener("click", async () => {
    runCapture.disabled = true;
    text("action-state", "capture running");
    stateClass("action-state", "warn");

    try {
      const response = await fetch(`${actionUrl}?action=capture`, {
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
      runCapture.disabled = false;
    }
  });
}

document.getElementById("refresh").addEventListener("click", () => {
  refresh().catch((error) => {
    text("generated-at", `status unavailable: ${error.message}`);
    stateClass("generated-at", "bad");
  });
});

refresh().catch((error) => {
  text("generated-at", `status unavailable: ${error.message}`);
  stateClass("generated-at", "bad");
});
