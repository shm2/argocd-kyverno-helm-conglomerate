#!/usr/bin/env bash
set -euo pipefail
# Pin all kubectl calls to the kubeadm cluster; don't affect kind.
export KUBECONFIG="${HOME}/.kube/k8scp2-admin.conf"
# Verify the primary Argo CD Application and its managed namespace resources.
kubectl -n argocd get application syncopts-lab
kubectl -n syncopts-lab get cm -l lab=argocd-sync-options
# Display actual synchronization options and ignoreDifferences configuration.
kubectl -n argocd get application syncopts-lab -o jsonpath='{.spec.syncPolicy.syncOptions}{"\n"}{.spec.ignoreDifferences}{"\n"}'
