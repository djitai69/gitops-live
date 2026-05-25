# gitops-live

GitOps configuration repository for the **dev** cluster. This repo is the live source of truth that ArgoCD watches and reconciles — every change merged here is automatically applied to the cluster.

---

## Context: Part of `platform-infra`

This repo is one component of a larger monorepo/multi-repo setup called **`platform-infra`**.

| Repo | Role |
|------|------|
| `platform-infra` | Houses Terraform, CI/CD pipelines, cluster provisioning, and tooling to *create* infrastructure |
| `gitops-live` (this repo) | Declares *what runs* on the cluster — ArgoCD watches this repo and drives the desired state |

The split exists by design: infrastructure provisioning code (Terraform, scripts) changes infrequently and is managed by the platform team, while the GitOps layer changes constantly as apps and platform components are deployed or updated. Keeping them separate means:

- No Terraform state in the same repo as Kubernetes manifests
- Smaller blast radius per change
- Clear ownership boundary — infra engineers own `platform-infra`, app/platform owners own `gitops-live`

---

## Repository Structure

```
gitops-live/
├── bootstrap/
│   └── argocd/
│       ├── bootstrap.sh      # One-time script to install ArgoCD and register the root app
│       ├── install.yaml      # ArgoCD installation manifests (pinned version)
│       └── root-app.yaml     # ArgoCD App-of-Apps entry point (watches clusters/dev/infrastructure)
├── clusters/
│   └── dev/
│       ├── infrastructure/   # ArgoCD Applications for cluster-level infra (ingress, cert-manager, etc.)
│       ├── platform/         # ArgoCD Applications for internal platform tooling
│       └── apps/             # ArgoCD Applications for user-facing applications
└── projects/                 # ArgoCD AppProject definitions (RBAC / source restrictions)
```

ArgoCD uses the **App-of-Apps** pattern: the root app points at `clusters/dev/infrastructure/`, which contains `Application` manifests that in turn point at the actual Helm charts or manifests for each component.

---

## How to Use

### Prerequisites

- `kubectl` configured against the target cluster
- Cluster-admin permissions

### 1. Bootstrap ArgoCD (first time only)

```bash
bash bootstrap/argocd/bootstrap.sh
```

This will:
1. Create the `argocd` namespace
2. Install ArgoCD from `bootstrap/argocd/install.yaml`
3. Wait for the ArgoCD server to become ready
4. Apply `root-app.yaml` — ArgoCD immediately starts reconciling the cluster

### 2. Access the ArgoCD UI

```bash
# Port-forward the ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get the initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Open `https://localhost:8080` and log in with `admin` and the password above.

### 3. Deploy a new application

1. Add an ArgoCD `Application` manifest under the appropriate directory:
   - `clusters/dev/apps/` — user-facing apps
   - `clusters/dev/platform/` — internal platform tooling
   - `clusters/dev/infrastructure/` — cluster-level infrastructure
2. Merge to `main` — ArgoCD picks up the change automatically and syncs.

### 4. Update an existing application

Edit the relevant manifest (e.g. bump a Helm chart version or change a value), open a PR, and merge. ArgoCD reconciles within the configured sync interval (default: 3 minutes) or immediately if webhooks are configured.

---

## Sync Policy

The root app (`infra-root`) is configured with:

```yaml
syncPolicy:
  automated:
    prune: true      # Removes resources deleted from git
    selfHeal: true   # Re-applies if someone manually edits the cluster
```

**Do not apply manifests directly to the cluster with `kubectl apply`.** Any manual change will be overwritten by ArgoCD on the next sync cycle.

---

## Onboarding a New Cluster

1. Create a new directory under `clusters/<env>/`
2. Add a new root `Application` pointing at that path
3. Update `root-app.yaml` or create a separate bootstrap entry for the new cluster
