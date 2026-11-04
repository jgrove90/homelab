#!/usr/bin/env python3
"""Computes a Talos + Kubernetes upgrade plan as a sequence of single-minor
hops, inserting Kubernetes "bridge" hops wherever the next Talos version
wouldn't support the Kubernetes version still running.

Usage: plan_upgrade.py <current_talos> <target_talos> <current_k8s> <target_k8s>
Prints a JSON list of {"type": "talos"|"k8s", "version": "X.Y.Z"} steps.

Why this exists: Talos does not support skipping minor versions on an
in-place upgrade, and neither does `talosctl upgrade-k8s --to`. Each Talos
release also only supports a sliding window of Kubernetes minor versions
(recorded in its own source as DefaultKubernetesVersion / SupportedKubernetesVersions
in pkg/machinery/constants/constants.go). This walks both chains one minor
at a time and only inserts a Kubernetes hop when the upcoming Talos version
actually requires it.
"""
import json
import re
import sys
import urllib.request

UA = {"User-Agent": "homelab-talos-upgrade-planner"}


def http_get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read().decode()


def minor(version):
    parts = version.split(".")
    return (int(parts[0]), int(parts[1]))


def list_releases(repo, max_pages=6):
    releases = []
    for page in range(1, max_pages + 1):
        data = json.loads(http_get(
            f"https://api.github.com/repos/{repo}/releases?per_page=100&page={page}"))
        if not data:
            break
        releases.extend(data)
        if len(data) < 100:
            break
    return releases


def latest_patch_for_minor(releases, major, minor_num):
    best = None
    pattern = re.compile(rf"^v{major}\.{minor_num}\.(\d+)$")
    for r in releases:
        if r.get("draft") or r.get("prerelease"):
            continue
        m = pattern.match(r["tag_name"])
        if m:
            patch = int(m.group(1))
            if best is None or patch > best:
                best = patch
    return f"{major}.{minor_num}.{best}" if best is not None else None


def talos_k8s_window(talos_version):
    """Returns (min_supported_k8s_minor, default_k8s_minor) for a Talos version."""
    text = http_get(
        f"https://raw.githubusercontent.com/siderolabs/talos/v{talos_version}"
        "/pkg/machinery/constants/constants.go")
    m_default = re.search(r'DefaultKubernetesVersion\s*=\s*"([\d.]+)"', text)
    m_count = re.search(r"SupportedKubernetesVersions\s*=\s*(\d+)", text)
    if not m_default or not m_count:
        raise RuntimeError(f"could not find Kubernetes support constants for Talos {talos_version}")
    default_minor = minor(m_default.group(1))[1]
    count = int(m_count.group(1))
    return (default_minor - (count - 1), default_minor)


def build_hop_list(repo, current_version, target_version):
    cur_major, cur_minor = minor(current_version)
    tgt_major, tgt_minor = minor(target_version)
    if cur_major != tgt_major:
        raise RuntimeError(f"major version change ({current_version} -> {target_version}) is not handled by this planner")
    if tgt_minor < cur_minor:
        raise RuntimeError(f"target {target_version} is older than current {current_version}")
    if tgt_minor == cur_minor:
        return []

    releases = list_releases(repo)
    hops = []
    for m in range(cur_minor + 1, tgt_minor + 1):
        version = latest_patch_for_minor(releases, cur_major, m)
        if version is None:
            raise RuntimeError(f"no release found for {repo} {cur_major}.{m}")
        hops.append(version)
    # Prefer the exact pinned target version (from variables.tf) for the last hop
    # over whatever the latest patch happened to be at plan time.
    if hops and minor(hops[-1]) == (tgt_major, tgt_minor):
        hops[-1] = target_version
    return hops


def plan(current_talos, target_talos, current_k8s, target_k8s):
    talos_hops = build_hop_list("siderolabs/talos", current_talos, target_talos)
    k8s_hops = build_hop_list("kubernetes/kubernetes", current_k8s, target_k8s)

    steps = []
    k8s_idx = 0
    cur_k8s_minor = minor(current_k8s)[1]

    for talos_version in talos_hops:
        min_minor, _ = talos_k8s_window(talos_version)
        while cur_k8s_minor < min_minor and k8s_idx < len(k8s_hops):
            steps.append({"type": "k8s", "version": k8s_hops[k8s_idx]})
            cur_k8s_minor = minor(k8s_hops[k8s_idx])[1]
            k8s_idx += 1
        if cur_k8s_minor < min_minor:
            raise RuntimeError(
                f"Talos {talos_version} requires Kubernetes minor >= {min_minor}, "
                f"but ran out of Kubernetes hops at {cur_k8s_minor} "
                f"(target Kubernetes {target_k8s} may be too old for target Talos {target_talos})")
        steps.append({"type": "talos", "version": talos_version})

    while k8s_idx < len(k8s_hops):
        steps.append({"type": "k8s", "version": k8s_hops[k8s_idx]})
        k8s_idx += 1

    return steps


def main():
    if len(sys.argv) != 5:
        print("usage: plan_upgrade.py <current_talos> <target_talos> <current_k8s> <target_k8s>", file=sys.stderr)
        sys.exit(2)
    current_talos, target_talos, current_k8s, target_k8s = sys.argv[1:5]
    try:
        steps = plan(current_talos, target_talos, current_k8s, target_k8s)
    except Exception as e:
        print(f"planning failed: {e}", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(steps))


if __name__ == "__main__":
    main()
