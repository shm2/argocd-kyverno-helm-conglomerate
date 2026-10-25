#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# BEFORE running this script:
# 1. Change validationActions from Audit to Deny in kyverno/policies/20-pod-label-audit.yaml.
# 2. Commit and push the Git change; let Argo CD report Synced.

# A dry-run Pod without lab-owner=gitops should be denied by Kyverno.
if kubectl -n sts-lab run denied-test --image=busybox:1.36 \
    --restart=Never --dry-run=server --command -- sh -c 'sleep 60'; then
  echo 'UNEXPECTED: unlabelled Pod was accepted; verify the Git-synced policy.' >&2
  exit 1
else
  echo 'EXPECTED: Kyverno DENIED the unlabelled test Pod.'
fi

# The legitimate StatefulSet Pods still satisfy the policy.
kubectl -n sts-lab get pods -l app.kubernetes.io/name=sts-web
