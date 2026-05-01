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

const linkLabel = (eth) => {
  if (!eth || !eth.present) return "missing";
  if (eth.carrier === "1") return `${eth.speed || "unknown"} ${eth.duplex || ""}`.trim();
  return eth.operstate || "down";
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
  const evidence = data.evidence || {};

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
  text("latest-capture", evidence.latest_capture || "none");
  text("latest-bench", evidence.latest_bench || "none");
  text("generated-at", data.generated_at);

  stateClass("mgmt-link", eth.carrier === "1" ? "ok" : "bad");
  stateClass("bcm-state", bcm.pci_present ? "ok" : "bad");
  stateClass("switchd", sw.running ? "ok" : "warn");
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
