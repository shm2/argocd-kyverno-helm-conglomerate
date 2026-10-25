#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Confirm that a server-side dry-run scaling attempt is denied by Kyverno.
# A denial is the intended result; it will not scale the real StatefulSet.
if kubectl -n sts-lab patch statefulset sts-web \
    --type=merge --dry-run=server -p '{"spec":{"replicas":5}}'; then
  echo 'UNEXPECTED: the five-replica request was accepted.' >&2
  exit 1
else
  echo 'EXPECTED: Kyverno rejected the attempted five-replica scale.'
fi

# Create ONE intentionally non-compliant Pod while the label policy is Audit.
# This Pod has no lab-owner label, so it should be allowed but reported.
kubectl -n sts-lab run label-violation \
  --image=busybox:1.36 --restart=Never --command -- sh -c 'sleep 300'

# PolicyReports are asynchronous; if no report yet, check again shortly.
kubectl -n sts-lab get policyreport -o wide

# After examining the report, delete only this intentionally non-compliant Pod.
# kubectl -n sts-lab delete pod label-violation
