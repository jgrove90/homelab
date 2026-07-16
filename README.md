# Homelab

This repository contains the infrastructure for my home lab. It combines Terraform for machine and virtualization provisioning with Kubernetes manifests managed through FluxCD.

The cluster configuration is GitOps-driven, with encrypted secrets handled through SOPS and Age. Application workloads are organized by environment and by category so the entire stack can be reconciled from version control.

## Architecture

```text
Internet
  |
[OPNsense] -- VLANs, firewall
  |
[Proxmox cluster]
  |
[Kubernetes cluster]
  |
  +-- FluxCD for GitOps reconciliation
  +-- SOPS + Age for secret decryption
  +-- Ingress, cert-manager, and external-dns
  +-- Application stacks and home services
```

## Repository Layout

```text
terraform/
  providers.tf
  variables.tf
  outputs.tf
  talos_config.tf
  virtual_machines.tf
  patch/

kubernetes/
  clusters/
    home/
      arr-stack/
      database/
      infra/
      media/
      utils/
```
 The `clusters/home/` directory contains the cluster-level configuration.

## Bootstrapping

### Prerequisites

- A reachable Kubernetes cluster.
- `flux`, `kubectl`, and `sops` installed locally.
- An Age keypair for SOPS encryption.

Generate an Age key if you do not already have one:

```bash
mkdir -p ~/.sops/age
age-keygen -o ~/.sops/age.agekey
```

### 1. Bootstrap Flux

Bootstrap Flux against this repository using the path that matches your cluster layout.

```bash
flux bootstrap github \
  --owner=jgrove90 \
  --repository=homelab \
  --branch=main \
  --path=kubernetes/clusters/home/infra/flux-system
```

If you bootstrap from a different directory structure, update the path so Flux points at the correct cluster overlay.

### 2. Add the Age key to the cluster

```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=~/.sops/age.agekey
```

### 3. Reconcile the cluster

```bash
flux reconcile kustomization home --with-source --namespace=flux-system
```

If you need to apply a specific encrypted manifest by hand, use the matching stack path under `kubernetes/clusters/home/`.

### 4. Watch reconciliation

```bash
flux get kustomizations --all-namespaces -w
flux logs --kind=Kustomization --follow
```

## Notes

- Kubernetes manifests are split between shared app bases and cluster-specific overlays.
- Secrets remain encrypted in git and are only decrypted in-cluster.
- Terraform manages the infrastructure layer that supports the cluster.