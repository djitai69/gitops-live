#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env if present
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

: "${GITHUB_USER:?GITHUB_USER must be set in .env or the environment}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f bootstrap/argocd/install.yaml

echo "Waiting for ArgoCD server deployment to become available..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# envsubst substitutes ${GITHUB_USER} in root-app.yaml before applying
# alternatively, if no substitution is needed: kubectl apply -f bootstrap/argocd/root-app.yaml
envsubst < bootstrap/argocd/root-app.yaml | kubectl apply -f -

echo "ArgoCD bootstrap complete."
kubectl get pods -n argocd

