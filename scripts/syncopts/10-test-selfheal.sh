#!/usr/bin/env bash
set -euo pipefail
# Pin kubectl to kubeadm and verify we're targeting only the lab resource.
export KUBECONFIG="${HOME}/.kube/k8scp2-admin.conf"
# Intentionally introduce live drift in a field Argo CD does NOT ignore.
kubectl -n syncopts-lab patch configmap syncopts-main --type=merge -p '{"data":{"message":"MANUALLY-DRIFTED"}}'
# Confirm the drift is visible before Argo CD heals it (it may heal quickly).
kubectl -n syncopts-lab get cm syncopts-main -o jsonpath='{.data.message}{"\n"}'
# A later verification should show hello-v1 (or the latest committed Git value).
echo 'Check: watch -n 3 "kubectl -n syncopts-lab get cm syncopts-main -o jsonpath={.data.message}; echo"'
