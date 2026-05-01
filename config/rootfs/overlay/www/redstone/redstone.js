const statusUrl = "/cgi-bin/redstone-status";

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
  text("generated-at", data.generated_at);

  stateClass("mgmt-link", eth.carrier === "1" ? "ok" : "bad");
  stateClass("bcm-state", bcm.pci_present ? "ok" : "bad");
  stateClass("switchd", sw.running ? "ok" : "warn");
  stateClass("sdk-ref", sdk.exists ? "ok" : "warn");
  stateClass("validation-summary", validation.fail_count > 0 ? "bad" : validation.warn_count > 0 ? "warn" : validation.log ? "ok" : "warn");
  stateClass("bench-validate-exit", bench.validate_exit === "0" ? "ok" : bench.validate_exit ? "bad" : "warn");
  stateClass("bde-smoke", bench.bde_smoke_exit === "0" ? "ok" : bench.bde_smoke_exit ? "bad" : "warn");
  stateClass("init-probe", probe.exists && probe.exit === "0" && !probe.unavailable ? "ok" : probe.exists ? "warn" : "warn");
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
