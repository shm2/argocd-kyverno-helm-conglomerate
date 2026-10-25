#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Delete ONLY this lab's two Argo CD Applications and its namespace.
# Be aware: application cascading deletion behavior may vary with finalizers.
# IMPORTANT: this lab's StatefulSet PVCs and its PVs use Retain semantics.
kubectl -n argocd delete application sts-web sts-lab-policies --ignore-not-found

# Remove lab workloads and namespaced policy objects, not shared components.
kubectl delete namespace sts-lab --ignore-not-found

# Display retained lab PVs for optional manual lifecycle handling later.
# Do NOT delete them automatically: they may contain data.
kubectl get pv | grep sts-lab || true

# Confirm unrelated GitOps Applications are unaffected.
kubectl -n argocd get applications
