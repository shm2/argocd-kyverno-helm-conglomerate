**GitHub account established: July 28, 2017**

> **Fast bootstrap:** Start with [START-HERE.md](START-HERE.md). This is the verified ZIP extraction → Git push → Argo CD deployment route.

# Three-node kubeadm | StatefulSet + Helm + Argo CD + Kyverno (GitOps)

Targets the existing cluster: **k8scp2 (8 GiB), k8s-w1 (4 GiB), k8s-w2 (4 GiB)**; Kubernetes 1.36.5; Argo CD 3.5.5; Kyverno 1.19.1 (Helm release already installed); NFS CSI StorageClass `nfs-argocd`.

This is an intentionally isolated lab. **DO NOT reinstall or upgrade the existing `kyverno` Helm release.** The first Argo Application renders the bundled Helm chart; the second manages two new *namespaced* Kyverno policy objects. Neither targets the `kyverno`, `argocd`, `pricelist`, or `argocd-substrate` namespace.

## Architecture

```text
Git repo
├── charts/sts-web/             Helm chart (3 ordinal Pods, headless Service, NFS PVCs)
├── kyverno/policies/           Modern CEL NamespacedValidatingPolicy CRs
└── argocd/apps/               Two Argo CD Applications, same local kubeadm cluster
      ├── sts-lab-policies      Kyverno policy objects
      └── sts-web               Helm-rendered StatefulSet

NFS CSI -> StorageClass nfs-argocd -> 3 independent RWO PVCs -> 3 PVs
``` 

## Preflight

```bash
# Make sure kubectl targets your three-node kubeadm cluster, not kind.
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Verify the engine, CRD, cluster and persistent storage are already available.
./scripts/00-preflight.sh
```

## Put the lab into **your own Git repository**

Create an empty repo you own in GitHub or another Git server accessible from `argocd-repo-server`. This package cannot guess your Git remote or push on your behalf.

```bash
# Unpack this ZIP and enter the working directory.
unzip kubeadm-sts-kyverno-gitops.zip
cd kubeadm-sts-kyverno-gitops

# REPLACE this example with the actual URL of a new empty repo YOU own.
export GITOPS_REPO_URL='https://github.com/YOUR_ACCOUNT/YOUR_REPO.git'

# Bind both Argo Applications to your real Git remote.
sed -i "s|REPLACE_WITH_YOUR_GIT_REPOSITORY|${GITOPS_REPO_URL}|g" argocd/apps/*.yaml

# Initialize and publish the complete GitOps project.
git init -b main
git add .
git commit -m 'Add StatefulSet and Kyverno GitOps labs'
git remote add origin "$GITOPS_REPO_URL"
git push -u origin main
```

If using an existing populated repository, copy the package contents into the repository and commit/push them there instead of creating an independent Git repository. If the repo is private, configure Argo CD repository credentials first.

## Bootstrap Argo CD Applications

```bash
# Select kubeadm; make sure the Git URL placeholders are replaced and pushed.
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Let Argo CD create the destination namespace and apply the CEL policies.
kubectl apply -f argocd/apps/10-sts-lab-policies.yaml

# Let Argo CD render and deploy the Helm chart in the same namespace.
kubectl apply -f argocd/apps/20-sts-web.yaml

# Inspect Application reconciliation and workload health.
kubectl -n argocd get applications sts-lab-policies sts-web
./scripts/20-verify.sh
```

The Applications auto-sync and self-heal. `helm list` will **not** show `sts-web`: Argo CD invokes Helm to render manifests but manages the resulting resources itself. `helm status kyverno -n kyverno` **does** show the existing independently Helm-managed Kyverno installation.

## StatefulSet persistence demonstration

```bash
# Writes unique test data into Pod ordinal 0's persistent NFS directory,
# recreates only that Pod, then reads back the same content.
./scripts/40-persistence-test.sh

# Inspect the stable storage identities and network identity details.
kubectl -n sts-lab get sts sts-web -o yaml
kubectl -n sts-lab get pvc -o wide
kubectl -n sts-lab get pods -o wide

# Test one ordinal's DNS name and HTTP response from another Pod.
kubectl -n sts-lab exec sts-web-1 -- \
  wget -qO- http://sts-web-0.sts-web-headless.sts-lab.svc.cluster.local:8080

# Optional web browser test from Windows through your trusted VMware network.
kubectl -n sts-lab port-forward --address 192.168.217.128 svc/sts-web 8082:8080
# Visit http://192.168.217.128:8082 while port-forward is running.
```

## Kyverno policies: audit, policy reports, enforcement

```bash
# Verify the namespaced policy resources; they do NOT apply outside sts-lab.
kubectl -n sts-lab get namespacedvalidatingpolicies

# Verify the <= 3 StatefulSet replicas guard with a server-side dry run,
# then create ONE intentionally unlabelled Pod while label policy is Audit.
./scripts/30-test-kyverno.sh

# Observe the eventually consistent reports; a dry-run does not create a report.
kubectl -n sts-lab get policyreport -o wide

# Remove the test Pod once you have examined the report.
kubectl -n sts-lab delete pod label-violation --ignore-not-found
```

**Policy promotion** (GitOps exercise): Edit `kyverno/policies/20-pod-label-audit.yaml`, changing `validationActions: [Audit]` (the two-line form) to `Deny`. Commit and push; Argo CD reconciles it. Then run `./scripts/35-test-deny-after-git-change.sh`, which checks that a server-side dry-run unlabelled Pod is rejected.

> `kubectl apply --dry-run=server` exercises admission without persisting resources. Actual failed admissions will not necessarily appear as stored-policy violations; inspect webhook error output. Reports concern existing/matching resources.

## GitOps StatefulSet experiments

- **Scale:** edit `charts/sts-web/values.yaml` `replicaCount: 3` -> `2`, commit and push. Watch `sts-web-2` disappear while `data-sts-web-2` PVC remains. Restore `3`; ordinal 2 reuses its claim.
- **Rolling update:** edit `rolloutMarker: "v1"` -> `"v2"`, commit/push, then `kubectl -n sts-lab rollout status statefulset/sts-web`. Changing the Pod template triggers a rolling replacement but preserves identities and PVCs.
- **Partitioned canary:** edit `rollingUpdate.partition: 2` together with `rolloutMarker: "v3"`. Commit/push. Only ordinal 2 receives the new Pod template until you reduce partition. Revert partition to 0 to complete the rollout.
- **Self-heal:** inspect desired replica count in Git. Direct `kubectl scale sts sts-web -n sts-lab --replicas=1` may be reverted automatically by Argo CD's `selfHeal: true`; use Git as the normal scaling interface.

## Cleanup — deliberately limited to sts-lab

```bash
# Verify correct cluster BEFORE invoking; this deletes the lab namespace.
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"
./scripts/90-cleanup.sh
```

The namespace deletion removes namespace-scoped PVC objects. The NFS PV reclaim policy is `Retain`, so released PVs and backing data **can remain** and need explicit manual handling. No cleanup script deletes NFS directories or preexisting applications.

## What the lab demonstrates

| Layer | Kubernetes/Argo CD/Kyverno component | Responsibility |
| --- | --- | --- |
| Desired state | Git | Versioned Helm values and policies |
| Rendering | Helm invoked by Argo CD | Turns chart templates into Kubernetes YAML |
| Reconciliation | Argo CD Applications | Apply, prune and self-heal declared resources |
| Workload identity | StatefulSet controller | Ordinals, named Pods, ordering and stable claims |
| Storage | PVC/PV/NFS CSI | Persist data beyond Pod recreation |
| Admission | Kyverno 1.19 CEL NamespacedValidatingPolicy | Audit or reject policy violations |
| Reporting | Kyverno PolicyReport | Display evaluations of live Kubernetes objects |

## Caveats

* The 3 replicas use two untainted workers with **preferred**, not required, anti-affinity. Two Pods may share one worker, and this demo has no replicated application-level data: it is **not** an HA database.
* The NFS server is `k8scp2`; its failure remains a storage single point of failure.
* PVC capacity of `1Gi` is a request, not automatically a hard per-directory NFS quota.
* Kyverno `NamespacedValidatingPolicy` uses `policies.kyverno.io/v1` (the current v1.19 form); the legacy `ClusterPolicy` / `Policy` objects are deprecated beginning in v1.19.
* Keep the existing direct-Helm `kyverno` release separate from Argo-managed *policies*. Migrating engine ownership from Helm to Argo CD needs an independent, deliberate cutover with careful CRD/webhook handling.

## Official references

- Kubernetes StatefulSets: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
- Argo CD Helm model: https://argo-cd.readthedocs.io/en/stable/user-guide/helm/
- Kyverno modern CEL validation: https://kyverno.io/docs/policy-types/validating-policy/
- Kyverno Argo CD integration: https://kyverno.io/docs/installation/platform-notes/
- Kyverno v1.19 API migration: https://kyverno.io/blog/2026/08/20/announcing-kyverno-release-1.19/

