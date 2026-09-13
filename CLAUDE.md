# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A homelab GitOps repo: Terraform provisions Talos Linux VMs on Proxmox, Talos forms a 3-node Kubernetes cluster, and FluxCD reconciles everything under `kubernetes/clusters/home/` from Git. Secrets are encrypted in Git with SOPS/Age and only decrypted in-cluster by Flux.

## Commands

### Terraform (infrastructure layer — VMs, Talos bootstrap, kubeconfig)
```bash
cd terraform
source env.sh          # sets TF_VAR_proxmox_api_token and friends (gitignored, not in repo)
terraform init
terraform apply        # provisions VMs, bootstraps Talos, writes talosconfig/kubeconfig, applies flux sops-age secret
terraform apply -replace=talos_cluster_kubeconfig.kubeconfig   # force-refresh kubeconfig before cert expiry
```
Generated files: `~/.talos/homelab/talosconfig`, `~/.kube/homelab-config`. Talos version, ISO filenames, and each `terraform/patch/*.yaml` `install.image` tag are three independent places that all encode the same Talos version — keep them in sync manually when bumping.

### Flux / cluster reconciliation
```bash
flux bootstrap github --owner=jgrove90 --repository=homelab --branch=main --path=kubernetes/clusters/home
kubectl --namespace=flux-system get secret sops-age     # verify SOPS decryption secret exists (Terraform manages this)
flux reconcile source git flux-system && flux reconcile kustomization flux-system --with-source
flux get kustomizations --all-namespaces -w
flux logs --kind=Kustomization --follow
```
Per-layer Kustomization names (namespace `flux-system`): `namespaces`, `repositories`, `cert-manager`, `cert-issuer`, `ddns-updater`, `intel-gpu-plugin`, `metallb-system`, `metallb-config`, `ingress-nginx`, `external-dns`, `services`, `apps`. Reconcile a specific one with `flux reconcile kustomization <name> --with-source`.

### Validating manifest changes before they reach Flux
```bash
kustomize build kubernetes/clusters/home/<layer>    # e.g. 4-apps, 3-services, 2-infra/<component>
```
This is the same check `.github/workflows/flux-app-image-update.yaml` runs (against `4-apps` only) before auto-merging Flux's image-update PRs — it only proves the YAML renders, not that it will apply or run cleanly, so render every layer you touched, not just the one CI happens to cover.

### Secrets (SOPS + Age)
```bash
sops kubernetes/clusters/home/<path>/secret.enc.yaml     # edit in place, re-encrypts on save
sops -d kubernetes/clusters/home/<path>/secret.enc.yaml  # view decrypted (requires local age key)
```
The Age recipient is in `.sops.yaml`; every secret file must match `*.enc.yaml` and encrypt only `data`/`stringData` (see `.sops.yaml`'s `encrypted_regex`). There is one Age keypair for the whole repo — losing it makes every encrypted secret unrecoverable.

## Architecture

### Layout and reconciliation order
`kubernetes/clusters/home/` is numbered to express Flux's dependency order, enforced via `dependsOn` in each layer's `flux-system/*-sync.yaml`:
```
0-namespaces → 1-repos → 2-infra/* → 3-services → 4-apps
```
- **0-namespaces**: all `Namespace` objects (`media`, `infra`, `utils`, `arr-stack`, `metallb-system`, `database`, `cnpg-system`, `cert-manager`). `flux-system` itself is created by `flux bootstrap`, not here.
- **1-repos**: `HelmRepository` sources, and per-app `ImageRepository`/`ImagePolicy` pairs + one `ImageUpdateAutomation` (`apps-img-update.yaml`) that writes tag bumps to the `app-image-update` branch under `4-apps`, using `# {"$imagepolicy": "flux-system:<name>"}` marker comments in the target Deployments. Not every app has a policy — some (`mealie`, `ntfy`, `wizarr`) are intentionally pinned and manually bumped. A policy with no marker, or a marker with no policy, is dead config, not a working automation.
- **2-infra**: MetalLB (`metallb-system` → `metallb-config` → `ingress-nginx`, in that dependency order since ingress-nginx needs a LoadBalancer IP from MetalLB's pool `192.168.1.110-150`), cert-manager → cert-issuer (one `ClusterIssuer` doing Cloudflare DNS-01, plus one wildcard `Certificate` per app namespace), external-dns (Cloudflare, `policy: upsert-only` — never deletes records it doesn't own), ddns-updater, intel-gpu-plugin.
- **3-services**: CloudNativePG operator + two single-instance Postgres `Cluster`s (`platform-db`, `immich-db`), and a Redis `StatefulSet`. Shared, cross-app infrastructure — not owned by any one app.
- **4-apps**: grouped by `arr-stack/`, `media/`, `utils/`; each app subdirectory follows the same shape (`deployment.yaml`, `service.yaml`, `ingress.yaml`, `pvc.yaml`, `pv.yaml`, optional `secret.enc.yaml`) with its own `kustomization.yaml`.

### Storage model
All persistent storage is static NFS from a single server, `192.168.1.13`. Every `PersistentVolume` in the repo follows the same convention: `storageClassName: ""`, `persistentVolumeReclaimPolicy: Retain`, and the matching `PersistentVolumeClaim` binds by explicit `spec.volumeName` (not by storage-class matching). CloudNativePG's PVs additionally bind via `claimRef` to the CNPG-generated PVC name (`<cluster>-1`). This means NFS data survives PVC/PV deletion (Retain), but a renamed PV/PVC pair breaks the explicit binding — treat any PV/PVC name change as a storage-affecting change. There is no backup mechanism (CNPG or otherwise) for this data in the repo.

### Hardware/node topology (Terraform + Talos)
Three Proxmox VMs: `talos-control-plane` and `talos-worker-01` on host `severen`, `talos-worker-02` on host `imre` (`terraform/virtual_machines.tf`). `worker-01` has Intel iGPU passthrough and is labeled `hardware.type=intel-gpu` via `terraform/patch/worker-01.yaml` kubelet `extraArgs`, with `/dev/dri` bind-mounted into the kubelet — this is what backs the `intel-gpu-plugin` DaemonSet's `gpu.intel.com/i915` resource, which GPU-using pods (currently just `plex`) request. Node-level config (hostnames, static IPs, DNS, disk, GPU passthrough, node labels) lives entirely in `terraform/patch/*.yaml` and is applied by Terraform/Talos, never by Kubernetes manifests — keep that separation when adding new node-level config.

### Networking
MetalLB hands out LoadBalancer IPs from `192.168.1.110-150`; ingress-nginx holds the pool's first IP (`192.168.1.110`) and is the entry point for all `Ingress` objects. external-dns watches Ingress/Service objects and manages Cloudflare DNS records for `alarlab.dev` and `packetsandpods.com`; most records are un-proxied (grey-cloud, resolving to the private ingress IP — LAN/VPN-only access) except where an ingress explicitly overrides with `external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"`. cert-manager issues one wildcard `*.alarlab.dev` certificate per app namespace against Let's Encrypt production (no staging issuer configured).

## Conventions to follow when adding or changing resources

- New Secrets: name the file `*.enc.yaml`, encrypt with `sops` against the recipient in `.sops.yaml` before committing. Never commit plaintext `stringData`/`data`.
- New Deployments: include `resources.requests`/`limits` and startup/readiness/liveness probes — every existing Deployment in this repo has them.
- New PV/PVC pairs: follow the existing static-binding pattern (`storageClassName: ""`, `persistentVolumeReclaimPolicy: Retain`, explicit `volumeName`) rather than introducing dynamic provisioning.
- New Flux Kustomizations go in the matching numbered layer and declare `dependsOn` for whatever they actually need ready first.
- New image automation: add both the `ImageRepository`/`ImagePolicy` in `1-repos/` **and** the `$imagepolicy` marker comment on the image line — one without the other is a no-op.
- Don't add a second NFS server, a second control-plane node, or HA Postgres instances "for best practice" — single-instance/single-NFS is this repo's deliberate homelab trade-off. If asked to improve reliability, prefer proposing backups over proposing redundancy.

## Destructive operations

Claude must stop and ask for explicit confirmation before executing any operation that could delete or irreversibly modify data or infrastructure.

This includes, but is not limited to:

- `rm`, `rm -rf`, recursive deletion, or equivalent filesystem operations
- `kubectl delete`
- deleting or recreating PVCs or PVs
- deleting namespaces
- deleting StatefulSets
- deleting databases or database clusters
- changing `persistentVolumeReclaimPolicy`
- modifying or deleting NFS-backed storage
- `terraform destroy`
- destructive Terraform changes affecting storage or networking
- formatting, partitioning, or wiping disks
- changing NFS exports or NAS permissions
- commands that recursively modify files on NFS-mounted paths

When a proposed change could affect persistent data, explicitly identify:

1. What data could be affected
2. What Kubernetes/storage resource is involved
3. Whether the underlying NFS data would remain intact
4. Whether the operation is reversible

Never delete persistent resources merely to resolve a reconciliation, deployment, or application error.

Prefer investigation and a reversible change first.

## Kubernetes operating model

This repository is GitOps-managed.

When a resource is managed by Flux:

- Prefer modifying the repository rather than making persistent changes directly with `kubectl`.
- Use `kubectl` primarily for inspection and diagnosis.
- Do not manually edit live resources as a substitute for changing the Git source of truth.
- Do not suspend, delete, or force Flux reconciliation to hide an underlying configuration problem without explicit approval.

Before applying a change to the cluster, explain what will change and why.
