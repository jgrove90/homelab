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
- `terraform`, `kubectl`, `flux`, and `sops` installed locally.
- An Age keypair for SOPS encryption.

Generate an Age key if you do not already have one:

```bash
mkdir -p ~/.sops
age-keygen -o ~/.sops/age.agekey
```

If your Age key lives somewhere else, set `sops_age_key_file_path` in Terraform before applying.

### 1. Provision Talos with Terraform

Terraform now writes a local `talosconfig` and `kubeconfig` automatically after the cluster is bootstrapped. By default the files are created at:

- `~/.talos/homelab/talosconfig`
- `~/.kube/homelab-config`

Set the Proxmox secret input via Terraform environment variables instead of a `.env` file:

```bash
edit terraform/env.sh
source terraform/env.sh
```

If you also want to override non-secret settings from the shell, Terraform will read matching variables such as `TF_VAR_proxmox_endpoint`, `TF_VAR_cluster_name`, or `TF_VAR_talos_cluster_health_timeout`.

Apply the infrastructure layer from the Terraform directory:

```bash
cd terraform
terraform init
terraform apply
```

Terraform also reconciles the Flux `sops-age` secret from `~/.sops/age.agekey` by default. The secret is applied with `kubectl`, so the private key is not stored in Terraform state.

The Talos health gate defaults to a `10m` wait with full Kubernetes checks enabled. If your first bootstrap is slow, tune `talos_cluster_health_timeout` instead of editing the module.

### 2. Bootstrap Flux

Bootstrap Flux against this repository using the path that matches your cluster layout.

```bash
flux bootstrap github \
  --owner=jgrove90 \
  --repository=homelab \
  --branch=main \
  --path=kubernetes/clusters/home/infra/flux-system
```

If you bootstrap from a different directory structure, update the path so Flux points at the correct cluster overlay.

### 3. Verify the SOPS key secret

Flux is configured to decrypt with the `sops-age` secret in `flux-system`, and Terraform now creates or updates that secret during apply. Verify it exists:

```bash
kubectl --namespace=flux-system get secret sops-age
```

If you disable `reconcile_flux_sops_age_secret`, create the secret manually with the same name before reconciling Flux.

### 4. Reconcile the cluster

```bash
flux reconcile kustomization home --with-source --namespace=flux-system
```

If you need to apply a specific encrypted manifest by hand, use the matching stack path under `kubernetes/clusters/home/`.

### 5. Watch reconciliation

```bash
flux get kustomizations --all-namespaces -w
flux logs --kind=Kustomization --follow
```

## Certificate Renewal

The generated kubeconfig is managed by Terraform through `talos_cluster_kubeconfig` with a renewal window of `2160h` (90 days). A regular `terraform apply` renews and rewrites the local kubeconfig before the client certificate expires.

The health gate that protects kubeconfig generation and the Flux SOPS secret reconcile is also configurable:

- `talos_cluster_health_timeout` controls how long Terraform waits for the cluster to become healthy.
- `talos_cluster_health_skip_kubernetes_checks` can relax the gate to Talos-only health checks, but the default `false` is the safer setting for this bootstrap flow.

If you want to force a kubeconfig refresh immediately, run:

```bash
cd terraform
terraform apply -replace=talos_cluster_kubeconfig.kubeconfig
```

The Talos client config file is also rewritten on each apply, so local file loss is recoverable as long as your Terraform state is intact. Store Terraform state securely and back it up, because it contains the Talos machine secrets used to recreate client access.

This repository does not rotate Talos machine secrets automatically. If you need to rotate Talos client credentials beyond the generated kubeconfig renewal flow, do that as an explicit maintenance action rather than replacing the cluster secrets casually.

## Notes

- Secrets remain encrypted in git and are only decrypted in-cluster.
- Terraform manages the infrastructure layer that supports the cluster.
- Proxmox authentication is API-token-only in Terraform; provide the token through `TF_VAR_proxmox_api_token`.