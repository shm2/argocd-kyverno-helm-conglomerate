#!/usr/bin/env bash
set -euo pipefail

# Select the existing three-node kubeadm cluster, not the kind context.
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Ensure the caller is inside the extracted project root.
if [[ ! -f charts/sts-web/Chart.yaml || ! -f argocd/apps/10-sts-lab-policies.yaml ]]; then
  echo 'ERROR: cd into kubeadm-sts-kyverno-gitops first.' >&2
  exit 2
fi

# Fail early when Applications still contain a placeholder Git URL.
if grep -q 'REPLACE_WITH_YOUR_GIT_REPOSITORY' argocd/apps/*.yaml; then
  echo 'ERROR: Publish the project to Git first: bash scripts/05-publish-gitops.sh URL' >&2
  exit 2
fi

# Verify existing infrastructure without reinstalling Kyverno/Argo CD/NFS CSI.
kubectl get node k8scp2
kubectl get storageclass nfs-argocd
kubectl api-resources --api-group=policies.kyverno.io | grep -i namespacedvalidating

# Ensure isolated namespace exists (safe if already created).
kubectl create namespace sts-lab --dry-run=client -o yaml | kubectl apply -f -

# Catch chart errors before Argo CD sync (NO direct helm install).
helm lint charts/sts-web

# Bootstrap policy Application FIRST; it creates two namespace-scoped CRs.
kubectl apply -f argocd/apps/10-sts-lab-policies.yaml

# Stop if Argo CD cannot fetch Git or reconcile policy manifests.
kubectl -n argocd wait application/sts-lab-policies \
  --for=jsonpath='{.status.sync.status}'=Synced --timeout=240s
kubectl -n sts-lab get namespacedvalidatingpolicies

# Now register the Helm-rendered StatefulSet application in Argo CD.
kubectl apply -f argocd/apps/20-sts-web.yaml

# Observe both Argo CD Applications and the new namespace only.
kubectl -n argocd get application sts-lab-policies sts-web
kubectl -n sts-lab get sts,pods,svc,pvc
