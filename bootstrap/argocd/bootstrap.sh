#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f bootstrap/argocd/install.yaml

echo "Waiting for ArgoCD server deployment to become available..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

kubectl apply -f bootstrap/argocd/root-app.yaml

echo "ArgoCD bootstrap complete."
kubectl get pods -n argocd

