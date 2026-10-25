#!/usr/bin/env bash
set -euo pipefail

# Select the existing three-node kubeadm cluster (NOT kind).
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Confirm expected context, storage provisioning, and preinstalled Kyverno engine.
kubectl get nodes -o wide
kubectl get storageclass nfs-argocd
helm status kyverno -n kyverno
kubectl -n kyverno get pods

# Kyverno v1.19.1 serves CEL-based namespace policy resources.
kubectl api-resources --api-group=policies.kyverno.io | grep -i namespacedvalidating

# Verify that existing application workloads are healthy before the lab.
kubectl -n argocd get applications
