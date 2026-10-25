#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Create an arbitrary file on the FIRST StatefulSet ordinal's own NFS PVC.
kubectl -n sts-lab exec sts-web-0 -- \
  sh -c 'date -u > /data/sts-proof.txt; cat /data/sts-proof.txt'

# Delete ONLY ordinal zero's Pod; its controller will recreate it.
kubectl -n sts-lab delete pod sts-web-0
kubectl -n sts-lab wait --for=condition=Ready pod/sts-web-0 --timeout=180s

# Prove the new Pod remounted the same persistent volume.
kubectl -n sts-lab exec sts-web-0 -- cat /data/sts-proof.txt

# Inspect PVC binding after Pod recreation.
kubectl -n sts-lab get pvc
