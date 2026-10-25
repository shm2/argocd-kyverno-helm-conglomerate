#!/usr/bin/env bash
set -euo pipefail

# Select the right cluster and show both new GitOps Applications.
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"
kubectl -n argocd get applications sts-lab-policies sts-web

# Show the StatefulSet, ordinal Pods, headless Service, and PVCs.
kubectl -n sts-lab get statefulset,pods,svc,pvc -o wide

# Verify the three stable ordinal Pods have become Ready.
for ordinal in 0 1 2; do
  kubectl -n sts-lab wait --for=condition=Ready "pod/sts-web-${ordinal}" --timeout=180s
  # Each Pod serves its own permanently stored HTML page.
  kubectl -n sts-lab exec "sts-web-${ordinal}" -- wget -qO- http://127.0.0.1:8080
  echo
done

# Display current Kyverno policies and any namespace policy reports.
kubectl -n sts-lab get namespacedvalidatingpolicies
kubectl -n sts-lab get policyreport -o wide
