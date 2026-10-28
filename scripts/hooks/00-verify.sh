#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/k8scp2-admin.conf}"
# Check Argo CD sync and last operation phase.
kubectl -n argocd get application hooks-lab
kubectl -n argocd get application hooks-lab -o jsonpath='{.status.operationState.phase}{"\n"}'
# Inspect the live workload and retained hook Jobs.
kubectl -n hooks-lab get deploy,pod,svc,cm,job
# Inspect logs from individual hook phases (if their Jobs exist).
for job in hooks-preflight hooks-sync-check hooks-smoke-test hooks-on-failure; do
  if kubectl -n hooks-lab get "job/$job" >/dev/null 2>&1; then
    echo "===== $job ====="
    kubectl -n hooks-lab logs "job/$job" --tail=12 || true
  fi
done
