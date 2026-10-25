#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Render the local chart without installing it to inspect exact generated YAML.
helm template sts-web ./charts/sts-web -n sts-lab > /tmp/sts-web-rendered.yaml

# Check Kubernetes admission/schema using API server dry-run (namespace must exist).
kubectl create namespace sts-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --dry-run=server -n sts-lab -f /tmp/sts-web-rendered.yaml

# Validate Kyverno v1.19 policy CRD schemas WITHOUT persisting policy objects.
kubectl apply --dry-run=server -n sts-lab -f kyverno/policies/
