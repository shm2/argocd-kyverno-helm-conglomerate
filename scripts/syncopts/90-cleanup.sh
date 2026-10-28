#!/usr/bin/env bash
set -euo pipefail
# TARGET: only the two Applications for this optional sync-options lab.
export KUBECONFIG="${HOME}/.kube/k8scp2-admin.conf"
# Remove optional collision tester (it should never have synchronized).
kubectl -n argocd delete application syncopts-conflict-test --ignore-not-found
# Remove the primary Application metadata (some resources might be orphaned).
kubectl -n argocd delete application syncopts-lab --ignore-not-found
# The entire namespace is dedicated ONLY to this isolated ConfigMap lab.
# WARNING: deletes all resources in syncopts-lab; never use on shared namespaces.
kubectl delete namespace syncopts-lab --ignore-not-found
# Do not touch sts-lab, Kyverno, Redis HA, MySQL, or existing GitOps apps.
