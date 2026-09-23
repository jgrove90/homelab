# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

---

# 1. Mission

This repository is both a **production-like homelab GitOps environment** and a **learning environment**.

Claude should help maintain the infrastructure while also helping the user develop practical skills in:

* Kubernetes
* GitOps / FluxCD
* Linux administration
* Talos Linux
* Terraform
* networking
* storage
* observability
* databases
* containerization
* distributed systems
* HPC / scientific computing patterns

The goal is not merely to make the homelab work. The goal is to understand **why it works** and develop the ability to design, troubleshoot, and operate similar systems independently.

## Learning-first behavior

When solving a problem:

1. **Investigate before changing anything.**
2. Explain the relevant architecture and likely cause.
3. Propose a solution and explain why it fits the existing architecture.
4. Prefer a small, reversible change.
5. Make the change only after the user understands what will happen when the change is consequential.
6. Validate the change.
7. Explain what was learned and what would be different in a larger production environment.

Do not unnecessarily automate away the learning opportunity.

For routine, low-risk operations, Claude may proceed directly.

For architectural or potentially destructive operations, stop and explain the decision before acting.

---

# 2. Repository Overview

This is a homelab GitOps repository:

```text
Terraform
    ↓
Proxmox
    ↓
Talos Linux
    ↓
Kubernetes
    ↓
FluxCD
    ↓
Git repository
```

Terraform provisions Talos Linux VMs on Proxmox.

Talos forms the Kubernetes cluster.

FluxCD reconciles Kubernetes resources from:

```text
kubernetes/clusters/home/
```

Secrets are encrypted in Git using SOPS/Age and decrypted in-cluster by Flux.

Git is the source of truth for persistent Kubernetes configuration.

---

# 3. Core Operating Principles

## Diagnose before modifying

When troubleshooting:

```text
Observe
  ↓
Form hypothesis
  ↓
Gather evidence
  ↓
Propose change
  ↓
Make smallest change
  ↓
Validate
  ↓
Document lesson
```

Do not immediately restart, delete, recreate, or reapply resources simply because they are unhealthy.

Prefer commands such as:

```bash
kubectl get
kubectl describe
kubectl logs
kubectl events
kubectl top
flux get
flux logs
talosctl get
talosctl logs
```

before modifying resources.

When possible, determine whether a problem exists in:

* Git
* Kustomize rendering
* Flux reconciliation
* Kubernetes objects
* scheduling
* networking
* storage
* container startup
* application configuration
* node/Talos configuration
* Proxmox infrastructure

Do not assume Kubernetes is the problem.

---

# 4. GitOps Operating Model

This repository is GitOps-managed.

When a resource is managed by Flux:

* Git is the source of truth.
* Prefer modifying the repository rather than manually changing live resources.
* Use `kubectl` primarily for inspection and diagnosis.
* Do not manually edit live resources as a substitute for changing Git.
* Do not suspend Flux merely to hide an underlying configuration problem.
* Do not delete Flux resources to force reconciliation.
* Do not use imperative `kubectl apply` for resources that should be managed by Flux unless explicitly troubleshooting or testing a change.

If a live resource differs from Git, investigate why before overwriting it.

Always distinguish between:

```text
Desired state
Git repository
```

and:

```text
Observed state
Kubernetes cluster
```

---

# 5. Existing Architecture

## Directory structure

```text
kubernetes/clusters/home/
├── 0-namespaces/
├── 1-repos/
├── 2-infra/
├── 3-services/
└── 4-apps/
```

Reconciliation order:

```text
0-namespaces
      ↓
1-repos
      ↓
2-infra
      ↓
3-services
      ↓
4-apps
```

Flux `dependsOn` relationships enforce this dependency order.

Do not introduce a different ordering convention without a specific architectural reason.

---

# 6. Kubernetes Conventions

When adding a new application, first inspect existing applications and follow the established repository pattern.

Do not introduce a new organizational pattern merely because another Kubernetes pattern exists.

Existing applications generally follow:

```text
deployment.yaml
service.yaml
ingress.yaml
pvc.yaml
pv.yaml
secret.enc.yaml
kustomization.yaml
```

Only include files that are actually required.

## Deployments

New Deployments should normally include:

* resource requests
* resource limits
* startup probe where appropriate
* readiness probe
* liveness probe where appropriate
* sensible security context
* explicit image tag or Flux image automation

Before creating a new Deployment, inspect similar applications and copy the repository's established conventions.

Do not blindly copy configuration that does not apply.

---

# 7. YAML Style

When modifying or creating Kubernetes YAML:

* Follow the formatting and structure of neighboring manifests.
* Preserve existing naming conventions.
* Preserve labels and selectors unless there is a reason to change them.
* Preserve namespace conventions.
* Preserve existing resource organization.
* Avoid unnecessary reformatting.
* Do not rewrite unrelated YAML.
* Keep diffs small and focused.

The existing repository is the primary style guide.

When multiple valid Kubernetes patterns exist, prefer the one already used in this repository unless there is a concrete reason to introduce a better pattern.

If a better pattern is identified, explain the trade-off before introducing it.

---

# 8. Adding New Services

When asked to add a service:

## Step 1 — Understand the application

Determine:

* container image
* required ports
* environment variables
* configuration files
* secrets
* persistent data
* dependencies
* health checks
* networking requirements
* resource requirements
* GPU requirements if applicable

## Step 2 — Inspect existing patterns

Find an existing application with similar requirements.

For example:

* database-backed application
* media application
* web application
* GPU application
* NFS-backed application
* application requiring ingress
* application requiring secrets

Use that application as the structural template.

## Step 3 — Determine dependencies

Ask:

```text
Does it need a namespace?
Does it need a HelmRepository?
Does it need a database?
Does it need Redis?
Does it need persistent storage?
Does it need ingress?
Does it need TLS?
Does it need DNS?
Does it need a GPU?
Does it need a Secret?
```

Place resources in the appropriate existing layer.

## Step 4 — Implement

Create the smallest set of manifests necessary.

Do not add infrastructure "just in case."

## Step 5 — Validate

Render the affected Kustomization:

```bash
kustomize build <path>
```

Then inspect the resulting resources.

## Step 6 — Explain

After implementation, explain:

* what was added
* how Flux will reconcile it
* how traffic reaches it
* where data is stored
* how secrets are handled
* how the application is exposed
* what failure modes exist
* what would change in a production environment

---

# 9. Architecture Review

Claude should actively identify architectural improvements when they are relevant.

Examples include:

* better resource requests/limits
* probes
* PodDisruptionBudgets
* NetworkPolicies
* security contexts
* RBAC
* service accounts
* backup strategies
* observability
* alerting
* persistent storage design
* database architecture
* GitOps dependency structure
* secret management
* image update automation
* resource scheduling
* node affinity
* topology spread
* ingress architecture
* DNS architecture
* GPU scheduling
* workload isolation

However:

**Suggestions are not automatic authorization.**

If an architectural improvement would significantly change the system, first explain:

```text
Current design
Proposed design
Why it is better
Trade-offs
Complexity introduced
Learning value
Failure modes
```

Then ask whether to implement it.

Do not introduce enterprise-scale complexity simply because it is considered "best practice."

This is a homelab and intentionally makes reasonable trade-offs.

---

# 10. Homelab Trade-offs

The following are deliberate architectural decisions.

Do not automatically "fix" them:

* single Kubernetes control plane
* single NFS server
* single-instance Postgres clusters
* static NFS PersistentVolumes
* MetalLB on the LAN
* Cloudflare DNS
* internal services exposed through ingress
* relatively small cluster
* limited hardware

If reliability improvements are requested, prefer:

```text
backup
restore testing
monitoring
alerting
documentation
```

before automatically recommending redundancy.

The goal is to understand the trade-off, not eliminate every source of failure.

---

# 11. Storage Architecture

Persistent storage currently uses static NFS from:

```text
192.168.1.13
```

PersistentVolumes generally use:

```yaml
storageClassName: ""
persistentVolumeReclaimPolicy: Retain
```

PVCs bind explicitly through:

```yaml
spec:
  volumeName: ...
```

CloudNativePG volumes additionally use `claimRef` for the generated PVC.

Treat PV/PVC names as storage-sensitive.

Renaming or recreating a PV/PVC can break the relationship between Kubernetes and the underlying data.

---

# 12. NAS Safety Boundary

## CRITICAL

The NAS is a protected data system.

Claude must treat NFS-backed storage as **read-only from the perspective of direct filesystem operations**.

Claude must never directly modify, delete, rename, move, or change permissions on NAS data.

Do not execute commands such as:

```bash
rm
rm -rf
mv
cp
rsync
find -delete
chmod
chown
truncate
dd
mkfs
```

against NFS-mounted paths.

Do not recursively modify files on NFS-mounted paths.

Do not modify NFS exports or NAS permissions.

Do not mount or remount NAS storage in a way that could alter data without explicit authorization.

The Kubernetes API may manage Kubernetes objects representing storage, but this does **not** grant permission to manipulate the underlying NAS filesystem.

When investigating storage problems:

1. Inspect Kubernetes PV.
2. Inspect PVC.
3. Inspect StorageClass configuration.
4. Inspect mount configuration.
5. Inspect pod mount information.
6. Inspect events.
7. Determine whether the issue is Kubernetes-side or NAS-side.
8. Prefer read-only investigation.

Never delete persistent Kubernetes resources merely to resolve an application problem.

---

# 13. Destructive Operations

Claude must stop and request explicit confirmation before executing an operation that could delete or irreversibly modify data or infrastructure.

Examples include:

```text
rm / rm -rf
kubectl delete
deleting namespaces
deleting StatefulSets
deleting databases
deleting database clusters
deleting PVCs
deleting PVs
changing reclaim policies
Terraform destroy
destructive Terraform changes
formatting disks
partitioning disks
wiping disks
changing NFS exports
changing NAS permissions
recursive modifications of NFS data
```

Before requesting confirmation, explain:

1. What will change.
2. What data could be affected.
3. Which Kubernetes/infrastructure resource is involved.
4. Whether the underlying data remains intact.
5. Whether the operation is reversible.
6. What safer alternatives exist.

Never hide a destructive operation inside another command or script.

---

# 14. Storage Changes

Before changing:

* PV names
* PVC names
* `volumeName`
* NFS paths
* reclaim policies
* database storage
* CNPG storage
* mount paths

explain the storage implications first.

For storage-related failures, prefer:

```text
inspect
diagnose
backup
repair
```

over:

```text
delete
recreate
```

---

# 15. Secrets

Secrets use SOPS + Age.

Secret files must use:

```text
*.enc.yaml
```

Never commit plaintext secrets.

Use:

```bash
sops <secret-file>
```

to edit encrypted secrets.

Use:

```bash
sops -d <secret-file>
```

only when necessary for inspection.

The Age recipient is defined in:

```text
.sops.yaml
```

There is currently one Age keypair for the repository.

Treat the Age private key as critical infrastructure.

Never print secret values unnecessarily.

Do not expose decrypted secrets in logs, commits, generated files, or command output when avoidable.

---

# 16. Validation

After changing Kubernetes manifests:

```bash
kustomize build <affected-layer>
```

Render every layer touched by the change.

Kustomize rendering proves that the manifests can be assembled, but does not prove that Kubernetes will successfully run them.

Where appropriate also validate:

```text
YAML syntax
Kubernetes schema
Flux configuration
image availability
resource dependencies
namespace existence
storage bindings
Ingress configuration
DNS configuration
secrets
```

After a change reaches the cluster, inspect:

```bash
kubectl get
kubectl describe
kubectl logs
kubectl events
flux get
flux logs
```

Do not declare success merely because `kustomize build` succeeds.

---

# 17. Flux Image Automation

Image automation consists of:

```text
ImageRepository
ImagePolicy
$imagepolicy marker
ImageUpdateAutomation
```

A policy without a marker is dead configuration.

A marker without a policy is dead configuration.

When adding image automation, verify both sides.

Some applications are intentionally pinned and manually updated.

Do not automatically add image automation to every application.

---

# 18. Networking

MetalLB provides LoadBalancer addresses from:

```text
192.168.1.110-150
```

Ingress-nginx uses:

```text
192.168.1.110
```

Ingress is the normal entry point for HTTP services.

external-dns manages DNS records.

Most services resolve to private LAN/VPN addresses.

Cloudflare proxying should only be enabled where explicitly intended.

When exposing a new service, determine:

```text
LAN only?
VPN access?
Internet accessible?
Ingress?
LoadBalancer?
DNS?
TLS?
Cloudflare proxy?
```

Do not expose a service externally by default.

---

# 19. Hardware and Scheduling

Node-level configuration belongs in Terraform/Talos configuration.

Do not move node-level configuration into Kubernetes simply because Kubernetes labels or DaemonSets can express something similar.

Current node-level concerns include:

* hostnames
* static IPs
* DNS
* disks
* GPU passthrough
* node labels
* kubelet configuration

GPU-specific workloads should use Kubernetes resource requests rather than assuming a GPU exists.

---

# 20. Debugging Applications

When an application fails, use this hierarchy:

```text
Git
 ↓
Kustomize
 ↓
Flux
 ↓
Kubernetes object
 ↓
Scheduler
 ↓
Pod
 ↓
Container
 ↓
Application
 ↓
Storage/network dependencies
```

Check the earliest failing layer first.

For example:

```text
Pod Pending
    ↓
inspect scheduler events
    ↓
check resources / node selectors / PVCs
```

rather than immediately restarting the pod.

For:

```text
CrashLoopBackOff
```

inspect:

```bash
kubectl logs
kubectl logs --previous
kubectl describe pod
```

before deleting the pod.

For:

```text
Ingress failure
```

inspect:

```text
Ingress
Service
Endpoints
Pod
Ingress controller
DNS
TLS
```

in that order.

---

# 21. Change Management

Prefer small commits and focused changes.

Do not combine unrelated cleanup with a functional change.

Avoid large automated rewrites of YAML.

Before modifying files:

```text
identify relevant files
inspect existing implementation
make focused change
review diff
validate
```

After changes, inspect:

```bash
git diff
git status
```

Do not commit changes unless explicitly requested.

---

# 22. When Claude Finds a Better Pattern

If Claude discovers a significantly better architecture than the current implementation:

Do not silently refactor the repository.

Instead explain:

```text
Current pattern:
...

Potential improvement:
...

Why:
...

Trade-offs:
...

What I would learn:
...

Risk:
...

Suggested migration:
...
```

Then let the user decide whether to pursue it.

For small improvements that are clearly consistent with existing conventions, Claude may implement them as part of the requested change.

---

# 23. Teaching Through Action

Whenever practical, connect the work to a broader infrastructure concept.

For example:

```text
"Your pod is Pending because..."
```

should ideally also explain:

```text
"This demonstrates Kubernetes scheduling: the scheduler cannot place
the pod until its resource/storage/node constraints are satisfied."
```

Likewise:

```text
"Flux isn't deploying it because..."
```

should explain the relevant reconciliation/dependency concept.

The user wants to learn by operating the system, so favor **hands-on diagnosis and incremental implementation** over purely theoretical explanations.

When appropriate, provide:

```text
What we're doing
Why we're doing it
Command/change
What to look for
What the result means
```

---

# 24. Commands

## Terraform

```bash
cd terraform
source env.sh
terraform init
terraform apply
terraform apply -replace=talos_cluster_kubeconfig.kubeconfig
```

Generated files:

```text
~/.talos/homelab/talosconfig
~/.kube/homelab-config
```

Talos version is represented independently in multiple places:

```text
Terraform configuration
terraform/patch/*.yaml
ISO filenames
```

Keep these synchronized when upgrading Talos.

---

## Flux

```bash
flux bootstrap github --owner=jgrove90 --repository=homelab --branch=main --path=kubernetes/clusters/home

flux reconcile source git flux-system

flux reconcile kustomization flux-system --with-source

flux get kustomizations --all-namespaces -w

flux logs --kind=Kustomization --follow
```

Specific Kustomization:

```bash
flux reconcile kustomization <name> --with-source
```

---

## Kustomize

```bash
kustomize build kubernetes/clusters/home/<layer>
```

Render every affected layer before considering a change complete.

---

## SOPS

```bash
sops kubernetes/clusters/home/<path>/secret.enc.yaml

sops -d kubernetes/clusters/home/<path>/secret.enc.yaml
```

---

# 25. Architecture Decision Records

This repository is also a history of *why*, not just *what*. Kubernetes manifests and Terraform show the current architecture, but they don't explain why one approach was chosen over another. Architecture Decision Records (ADRs) preserve that reasoning so future Claude sessions (and future you) don't have to reverse-engineer it or accidentally re-litigate a settled trade-off.

## Location and format

ADRs live under:

```text
docs/architecture/decisions/
```

One file per decision, named:

```text
NNNN-short-title.md
```

Numbers are sequential and never reused (e.g. `0001-single-nfs-server.md`, `0002-metallb-on-lan.md`).

Each ADR is a single markdown file with these fields:

```text
# NNNN. Title

Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded by NNNN | Deprecated

## Context
What situation or problem prompted this decision.

## Decision
What was decided.

## Alternatives considered
Other options that were evaluated and why they weren't chosen.

## Trade-offs / consequences
What this decision costs and what it buys, including known limitations.

## Future reconsideration conditions
What would change (scale, hardware, reliability needs) that should trigger revisiting this decision.
```

Keep entries concise and practical — a page or less. This is a homelab record, not enterprise documentation. Bullet points are fine; prose is not required.

## When to create an ADR

Create an ADR for decisions with lasting architectural weight, such as:

* choosing between competing architectural approaches
* introducing or removing a piece of infrastructure
* changing storage architecture
* changing networking architecture
* changing database architecture
* making an intentional homelab trade-off (see [Section 10](#10-homelab-trade-offs))
* adopting a new Kubernetes pattern

Do **not** create an ADR for routine changes: bumping an image tag, adjusting resource limits, fixing a typo, adding a straightforward app that follows an existing pattern, or any other change that doesn't alter the reasoning behind the architecture. Most YAML changes need no ADR at all.

## Before proposing architectural changes

Check `docs/architecture/decisions/` for an existing ADR before proposing a change that might conflict with a previous architectural decision. If a relevant ADR exists, surface it and explain how the new proposal relates to it (compatible, or would need to supersede it) before proceeding.

## ADRs are immutable records, not living documents

An ADR captures the decision and the reasoning *at the time it was made*. Do not edit an old ADR just because the decision later turns out to have drawbacks — that would erase the historical record of what was known and why the choice made sense then.

If a decision changes, write a **new** ADR that supersedes the old one, and update the old ADR's `Status` line to `Superseded by NNNN`. The old file's Context/Decision/Trade-offs sections stay as originally written.

## Creating historical ADRs

Do not invent an ADR for a past decision unless the reasoning can be confidently determined from the repository, commit history, or prior conversation. If the rationale is unclear or only partially known, either skip it or write the ADR with the uncertain parts explicitly marked (e.g. `Context: unknown — inferred from commit history, not confirmed with user`) rather than fabricating a plausible-sounding justification.

## Example ADR template

```markdown
# 0001. Use a single NFS server for persistent storage

Date: 2026-01-15
Status: Accepted

## Context
The cluster needs shared persistent storage for stateful workloads
(databases, media libraries). Options were a single NFS server,
a distributed storage system (e.g. Ceph/Rook), or per-node local storage.

## Decision
Use a single NFS server (192.168.1.13) exposing static NFS-backed
PersistentVolumes, bound explicitly via volumeName.

## Alternatives considered
- Rook/Ceph: more resilient, but adds significant operational complexity
  and hardware overhead for a small homelab cluster.
- Local storage per node: simpler but ties data to a single node and
  complicates pod rescheduling.

## Trade-offs / consequences
- Single point of failure for all persistent storage.
- Simple to operate, understand, and back up.
- Static PV/PVC bindings require care when renaming or recreating.

## Future reconsideration conditions
Revisit if the NFS server becomes a reliability problem in practice,
or if cluster scale/workload count justifies the operational cost of
a distributed storage system.
```

---

# 26. Final Decision Rule

When choosing between multiple valid approaches, prefer the approach that:

1. Fits the existing repository.
2. Is simple.
3. Is reversible.
4. Is observable.
5. Is GitOps-compatible.
6. Protects persistent data.
7. Minimizes unnecessary infrastructure.
8. Provides a useful learning opportunity.
9. Can later be evolved toward production-grade architecture.

The goal is not to build the most complicated homelab.

The goal is to build a system that is **useful, understandable, reproducible, safe to experiment with, and capable of teaching real infrastructure engineering skills.**
