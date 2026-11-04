#!/usr/bin/env bash
set -euo pipefail

# Walks through a Talos OS + Kubernetes upgrade, one step at a time, narrating
# what each command does and why before it runs.
#
# Default mode is DRY RUN: every step is explained but nothing is executed
# against the cluster. Pass --exec to actually run commands — even then,
# each individual command still requires a y/N confirmation.
#
# Targets come from variables.tf (talos_os_version, kubernetes_version) and
# patch/*.yaml (install image hashes) — edit those, then just run this
# script. Current versions are read live from the cluster. Everything in
# between — which intermediate Talos/Kubernetes minor versions to hop
# through, and where a Kubernetes "bridge" hop needs to land relative to
# the Talos hops — is computed automatically (see plan_upgrade.py below),
# not hand-curated.
#
# Lessons baked into this, learned the hard way on a previous 1.9.4 -> 1.14.5
# upgrade:
#
#   1. Talos does not support skipping minor versions on an in-place upgrade.
#      Walk every intermediate minor version, one node at a time. Same rule
#      applies to `talosctl upgrade-k8s --to` for Kubernetes.
#
#   2. Your local talosctl client version matters. If it's older than the
#      target image, Talos falls back to a legacy upgrade protocol that can
#      fail outright ("task upgrade failed: exit code 4"). This script warns
#      if your client is older than the target but can't fix it itself —
#      upgrading a binary outside this repo needs you to run it.
#
#   3. Kubernetes support ranges shift per Talos release. Talos's own source
#      tree records this per release as two constants in
#      pkg/machinery/constants/constants.go: DefaultKubernetesVersion (the
#      newest Kubernetes minor that version targets) and
#      SupportedKubernetesVersions (how many minors back from that, inclusive,
#      it supports). This script reads those directly from GitHub for each
#      Talos hop to decide whether Kubernetes needs to catch up first.
#
#   4. Single-instance CNPG (or any) database pods with no replica have a
#      PodDisruptionBudget that will NEVER allow voluntary eviction
#      (disruptionsAllowed stays 0 — there's nothing to fail over to). A
#      node drain will hang against this and eventually time out, leaving
#      the node cordoned and un-upgraded. This script checks for that
#      before draining each node and tells you what to do about it; it
#      will not silently plow through it.
#
# Requires network access to api.github.com and raw.githubusercontent.com
# to resolve release versions and support windows.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXEC=false
if [[ "${1:-}" == "--exec" ]]; then
  EXEC=true
fi

get_var_default() {
  local var_name="$1"
  sed -n "/variable \"$var_name\"/,/^}/p" "$REPO_ROOT/variables.tf" \
    | grep default \
    | sed -E 's/.*=\s*"([^"]*)".*/\1/'
}

get_install_image_base() {
  local patch_file="$1"
  grep 'image:' "$REPO_ROOT/patch/$patch_file" \
    | sed -E 's/^\s*image:\s*//' \
    | sed -E 's/:v[0-9.]+$//'
}

CP_IP=$(get_var_default talos_control_plane_ip_addr)
WORKER01_IP=$(get_var_default talos_worker_01_ip_addr)
WORKER02_IP=$(get_var_default talos_worker_02_ip_addr)
TARGET_TALOS=$(get_var_default talos_os_version)
TARGET_K8S=$(get_var_default kubernetes_version)

CP_IMAGE_BASE=$(get_install_image_base control-plane.yaml)
WORKER01_IMAGE_BASE=$(get_install_image_base worker-01.yaml)
WORKER02_IMAGE_BASE=$(get_install_image_base worker-02.yaml)

NODE_NAMES=(control-plane worker-01 worker-02)
NODE_IPS=("$CP_IP" "$WORKER01_IP" "$WORKER02_IP")
NODE_IMAGE_BASES=("$CP_IMAGE_BASE" "$WORKER01_IMAGE_BASE" "$WORKER02_IMAGE_BASE")

HEALTH_CMD="talosctl health --control-plane-nodes $CP_IP --worker-nodes $WORKER01_IP,$WORKER02_IP --endpoints $CP_IP"

CURRENT_TALOS=$(talosctl version --nodes "$CP_IP" --short 2>/dev/null | sed -n 's/^\s*Tag:\s*v//p')
CURRENT_K8S=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null | sed 's/^v//')
CLIENT_TALOS=$(talosctl version --client --short 2>/dev/null | sed -n 's/^\s*Talos\s*v//p')

if [[ -z "$CURRENT_TALOS" || -z "$CURRENT_K8S" ]]; then
  echo "Could not read current Talos/Kubernetes versions from the live cluster. Is talosctl/kubectl configured?" >&2
  exit 1
fi

echo "Current:  Talos $CURRENT_TALOS / Kubernetes $CURRENT_K8S"
echo "Target:   Talos $TARGET_TALOS / Kubernetes $TARGET_K8S"
echo "Client:   talosctl $CLIENT_TALOS"

if [[ "$CURRENT_TALOS" == "$TARGET_TALOS" && "$CURRENT_K8S" == "$TARGET_K8S" ]]; then
  echo "Already at the target versions. Nothing to do."
  exit 0
fi

python3 -c "
import sys
def v(s): return tuple(int(x) for x in s.split('.')[:2])
sys.exit(0 if v('$CLIENT_TALOS') >= v('$TARGET_TALOS') else 1)
" || echo "WARNING: local talosctl client ($CLIENT_TALOS) is older than the target ($TARGET_TALOS). Upgrade it first — an older client can make Talos fall back to a legacy upgrade protocol that fails outright."

echo
echo "Computing upgrade plan (talking to api.github.com / raw.githubusercontent.com)..."
PLAN=$(python3 "$SCRIPT_DIR/plan_upgrade.py" "$CURRENT_TALOS" "$TARGET_TALOS" "$CURRENT_K8S" "$TARGET_K8S")
echo "Plan:"
echo "$PLAN" | python3 -c "
import json, sys
for step in json.load(sys.stdin):
    print(f\"  {step['type']:5s} -> {step['version']}\")
"

step() {
  local what="$1" why="$2" cmd="$3" look_for="$4" means="$5"

  echo
  echo "────────────────────────────────────────────────────────────────"
  echo "WHAT:     $what"
  echo "WHY:      $why"
  echo "COMMAND:  $cmd"
  echo "LOOK FOR: $look_for"
  echo "MEANS:    $means"
  echo "────────────────────────────────────────────────────────────────"

  if ! $EXEC; then
    read -rp "(dry run — not executed) press ENTER for next step... " _
    return
  fi

  read -rp "Run this now? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    eval "$cmd"
  else
    echo "Skipped — you'll need to handle this step manually before continuing."
  fi
}

# Read-only safety check, always runs (even in dry run) since it touches
# nothing. Finds pods on $1 (a node name, e.g. "worker-02") that are covered
# by a PodDisruptionBudget with zero allowed disruptions — those pods will
# never voluntarily evict, so a drain of this node will hang and time out.
check_pdb_blockers() {
  local node="$1"
  echo
  echo "Checking for PodDisruptionBudgets that would block draining $node..."
  python3 - "$node" <<'PYEOF'
import json, subprocess, sys

node = sys.argv[1]
pdbs = json.loads(subprocess.run(
    ["kubectl", "get", "pdb", "-A", "-o", "json"],
    capture_output=True, text=True, check=True).stdout)

blockers = []
for pdb in pdbs.get("items", []):
    if pdb.get("status", {}).get("disruptionsAllowed", 1) != 0:
        continue
    ns = pdb["metadata"]["namespace"]
    selector = pdb.get("spec", {}).get("selector", {}).get("matchLabels", {})
    if not selector:
        continue
    label_selector = ",".join(f"{k}={v}" for k, v in selector.items())
    pods = json.loads(subprocess.run(
        ["kubectl", "get", "pods", "-n", ns, "-l", label_selector, "-o", "json"],
        capture_output=True, text=True, check=True).stdout)
    for pod in pods.get("items", []):
        if pod.get("spec", {}).get("nodeName") == node:
            blockers.append((ns, pod["metadata"]["name"], pdb["metadata"]["name"]))

if blockers:
    print(f"BLOCKED: {len(blockers)} pod(s) on {node} are covered by a PDB with 0 allowed disruptions:")
    for ns, pod, pdb_name in blockers:
        print(f"  - {ns}/{pod}  (blocked by PDB {ns}/{pdb_name})")
    print()
    print("These will NOT voluntarily evict — the drain will hang until it times out,")
    print(f"leaving {node} cordoned and un-upgraded.")
    print()
    print("To proceed: cordon the node first so they don't reschedule right back onto")
    print("it, then directly delete the blocking pod(s) (a direct delete bypasses the")
    print("PDB's eviction check — the pod still gets a normal, clean shutdown):")
    print(f"    kubectl cordon {node}")
    for ns, pod, _ in blockers:
        print(f"    kubectl -n {ns} delete pod {pod}")
    print("Then confirm the pod(s) rescheduled healthy elsewhere before continuing.")
    sys.exit(1)
else:
    print(f"No PDB blockers found for {node}.")
PYEOF
}

upgrade_node() {
  local name="$1" ip="$2" image="$3"

  if ! check_pdb_blockers "$name"; then
    echo
    read -rp "Resolve the blockers above, then press ENTER to continue (or Ctrl-C to abort)... " _
  fi

  step \
    "Upgrade $name ($ip) to $image" \
    "One minor version, one node at a time — if this image/version has a problem, it only affects this one node." \
    "talosctl upgrade --nodes $ip --image $image" \
    "talosctl streams the upgrade/reboot events and exits without error." \
    "$name is now running $image."
}

verify_node() {
  local name="$1" ip="$2"
  step \
    "Verify $name ($ip) came back healthy" \
    "Never move to the next node or hop while this one is still settling." \
    "talosctl version --nodes $ip --short && $HEALTH_CMD" \
    "Version shows the expected tag; health check ends with every check OK." \
    "Safe to continue."
}

upgrade_k8s() {
  local target="$1"
  step \
    "Upgrade Kubernetes to $target" \
    "talosctl upgrade-k8s handles control plane components and kubelet config across every node in the correct order — a single cluster-wide operation, not per-node. It rejects multi-minor jumps, same as the OS upgrade." \
    "talosctl upgrade-k8s --to $target" \
    "talosctl prints each component (kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, ...) being updated across nodes." \
    "The Kubernetes control plane and kubelets are now on $target."
}

verify_cluster() {
  step \
    "Verify the whole cluster" \
    "Confirm every node is healthy before the next hop." \
    "$HEALTH_CMD && kubectl get nodes -o wide" \
    "All nodes Ready." \
    "Safe to continue."
}

echo
echo "Talos/Kubernetes upgrade walkthrough"
echo "  control plane: $CP_IP  -> $CP_IMAGE_BASE"
echo "  worker-01:     $WORKER01_IP  -> $WORKER01_IMAGE_BASE"
echo "  worker-02:     $WORKER02_IP  -> $WORKER02_IMAGE_BASE"
if $EXEC; then
  echo "  mode: EXEC (will prompt before each command)"
else
  echo "  mode: DRY RUN (narration only, nothing will execute)"
fi

step \
  "Check current cluster health and versions before changing anything" \
  "Establishes a known-good baseline so we can tell whether any later failure was caused by the upgrade or pre-existing." \
  "$HEALTH_CMD && kubectl get nodes -o wide" \
  "All nodes Ready, health check reports no errors." \
  "If the cluster isn't healthy now, stop and fix that first — do not upgrade on top of an existing problem."

while IFS=$'\t' read -r step_type step_version; do
  if [[ "$step_type" == "talos" ]]; then
    for i in "${!NODE_NAMES[@]}"; do
      name="${NODE_NAMES[$i]}"
      ip="${NODE_IPS[$i]}"
      image="${NODE_IMAGE_BASES[$i]}:v${step_version}"
      upgrade_node "$name" "$ip" "$image"
      verify_node "$name" "$ip"
    done
  else
    upgrade_k8s "$step_version"
    verify_cluster
  fi
done < <(echo "$PLAN" | python3 -c "
import json, sys
for s in json.load(sys.stdin):
    print(f\"{s['type']}\t{s['version']}\")
")

step \
  "Final verification" \
  "Confirm the whole cluster — OS and Kubernetes — is healthy on the new versions." \
  "$HEALTH_CMD && kubectl get nodes -o wide && kubectl version" \
  "All nodes Ready, kubectl version shows server version $TARGET_K8S." \
  "Upgrade complete."

echo
echo "Done."
