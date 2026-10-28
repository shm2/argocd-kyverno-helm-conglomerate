#!/usr/bin/env bash
set -euo pipefail
# Pin kubectl to kubeadm.
export KUBECONFIG="${HOME}/.kube/k8scp2-admin.conf"
# Change ONLY the field covered by Application.spec.ignoreDifferences.
kubectl -n syncopts-lab patch cm syncopts-main --type=merge -p '{"data":{"runtime":"externally-set"}}'
# Request a new diff calculation; do not sync or delete the app.
kubectl -n argocd annotate application syncopts-lab argocd.argoproj.io/refresh=hard --overwrite
# Verify the Application remains Synced once it has refreshed, and live value persists.
kubectl -n syncopts-lab get cm syncopts-main -o jsonpath='{.data.runtime}{"\n"}'
kubectl -n argocd get application syncopts-lab
