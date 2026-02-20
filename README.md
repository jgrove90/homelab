**My homelab** — a GitOps-powered Kubernetes setup running at home in Colorado.  
Declarative infrastructure with Terraform, continuous delivery via FluxCD, encrypted secrets using SOPS + Age, and helpful automation scripts.

## Homelab Banner TODO

## 🏗️ High-Level Architecture

```
Internet
   │
[OPNsense] ── VLANs, Firewall, Reverse Proxy
   │
[Proxmox Cluster]
   │
   └─ Kubernetes Cluster
         │
         ├─ FluxCD (GitOps reconciler)
         ├─ SOPS + Age (decryption in-cluster)
         ├─ Ingress / Cert-Manager / External-DNS
         └─ Apps (Immich, Home Assistant, monitoring, etc.)
```

## 🚀 Bootstrap / Quick Start

### Prerequisites
- A working Kubernetes cluster (k3s, Talos, vanilla, etc.)
- `flux` CLI installed (`brew install fluxcd/tap/flux` or similar)
- `kubectl` access to your cluster
- Age keypair generated:  
  ```bash
  mkdir -p ~/.sops/age
  age-keygen -o ~/.sops/age/keys.txt
  ```
- This repo cloned or forked

### 1. Bootstrap Flux
```bash
flux bootstrap github \
  --owner=jgrove90 \
  --repository=homelab \
  --branch=main \
  --path=clusters/homelab
```

### 3. Add your Age key to the cluster
```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=~/.sops/age/age.agekey
```

### 4. Apply encrypted secrets
```bash
sops --decrypt kubernetes/flux-system/config-secret.enc.yaml | kubectl apply -f -
```

### 5. Watch reconciliation
```bash
flux get kustomizations --all-namespaces -w
# or
flux logs --kind=Kustomization --follow
```

## 📂 Repository Structure TODO


Made with ☕ in Colorado  
Last updated: February 2026