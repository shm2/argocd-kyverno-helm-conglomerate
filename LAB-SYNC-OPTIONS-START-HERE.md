# Argo CD 3.5 Sync Options — kubeadm isolated GitOps lab

This add-on is designed to be **unzipped directly at the root** of the already-published
`~/kubeadm-sts-kyverno-gitops` repository. It adds new files only (no edits to `sts-web`,
Kyverno, Redis, or MySQL). Namespace: `syncopts-lab` (will be created by Argo CD).

## Bootstrap (after transferring ZIP from Windows to k8scp2)

```bash
# Select the kubeadm context and enter the existing GitOps repository.
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"
cd ~/kubeadm-sts-kyverno-gitops

# Extract the ZIP INTO this directory (not a separate nested directory).
unzip -o ~/argocd-sync-options-addon.zip

# Check that repository name and branch match the existing published project.
git remote -v
git branch --show-current

# Commit and publish the new lab manifests; Argo CD reads from GitHub.
git add argocd/apps/30-syncopts-lab.yaml argocd/apps/31-syncopts-conflict-test.yaml labs/sync-options scripts/syncopts LAB-SYNC-OPTIONS-START-HERE.md
git commit -m 'Add isolated Argo CD sync options lab'
git push origin main

# Register ONLY the new lab Application; it will sync automatically.
kubectl apply -f argocd/apps/30-syncopts-lab.yaml

# Observe reconciliation and the four ConfigMaps (all should be present).
watch -n 3 'kubectl -n argocd get application syncopts-lab; kubectl -n syncopts-lab get cm -l lab=argocd-sync-options'
```

## Exercise 1 — Manual vs auto sync

`automated.enabled=false` means Argo CD detects OutOfSync **without applying** Git changes.

```bash
# Temporarily disable automatic sync on this standalone Application ONLY.
kubectl -n argocd patch application syncopts-lab --type=merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":false}}}}'

# Change the Git desired value, then push it.
sed -i 's/message: "hello-v1"/message: "hello-v2"/' labs/sync-options/resources/10-main.yaml
git add labs/sync-options/resources/10-main.yaml
git commit -m 'Demonstrate manual Argo CD sync'
git push origin main

# Recalculate Git vs cluster (manual mode should remain OutOfSync).
kubectl -n argocd annotate application syncopts-lab argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application syncopts-lab

# Re-enable automated sync and observe convergence without pressing Sync.
kubectl -n argocd patch application syncopts-lab --type=merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":true}}}}'
watch -n 3 'kubectl -n argocd get application syncopts-lab; kubectl -n syncopts-lab get cm syncopts-main -o yaml | grep -A 3 "^data:"'
```

## Exercise 2 — selfHeal=true

```bash
# Update a live, NON-ignored field; Argo CD should revert it to the Git value.
bash scripts/syncopts/10-test-selfheal.sh
```

## Exercise 3 — ignoreDifferences + RespectIgnoreDifferences

```bash
# Change the field /data/runtime which Argo CD ignores for this ConfigMap.
bash scripts/syncopts/20-test-ignore.sh

# To demonstrate behavior during a real sync, edit Git's message field again,
# commit and push, then confirm /data/runtime stays externally-set.
```

## Exercise 4 — automatic pruning and PruneLast=true

```bash
# Remove only the prunable ConfigMap's manifest from your local Git repository.
rm labs/sync-options/resources/20-prunable.yaml
git add -A labs/sync-options/resources
git commit -m 'Test Argo CD automatic prune in isolated lab'
git push origin main

# Argo CD should delete syncopts-prunable; other lab ConfigMaps remain.
watch -n 3 'kubectl -n syncopts-lab get cm -l lab=argocd-sync-options'
```

## Exercise 5 — resource-level override Prune=false

Remove `labs/sync-options/resources/30-protected.yaml` from Git, commit/push. Because
its live object carries `argocd.argoproj.io/sync-options: Prune=false`, Argo CD
will **not** prune it, and the Application can remain OutOfSync. Restore the YAML
with `git restore --source=HEAD~1 -- labs/sync-options/resources/30-protected.yaml`,
commit, and push to return to a clean desired state. This is optional because a
permanent skip causes a deliberately persistent OutOfSync state.

The ConfigMap `syncopts-override` demonstrates the other per-resource override:
`ServerSideApply=false` while the rest of the Application uses SSA.

## Exercise 6 — FailOnSharedResource=true (EXPECTED FAIL; optional)

```bash
# Register the manual contender; it targets exactly one already-owned ConfigMap.
kubectl apply -f argocd/apps/31-syncopts-conflict-test.yaml

# In Argo CD UI, open syncopts-conflict-test and click SYNC.
# EXPECTED: shared resource error. No other workloads should be touched.

# Remove the deliberately failed tester after observing the admission by Argo CD.
kubectl -n argocd delete application syncopts-conflict-test --ignore-not-found
```

## What the eight specified syncOptions do

- `Validate=true`: perform Kubernetes schema validation (normal behavior).
- `ApplyOutOfSyncOnly=true`: apply only resources considered OutOfSync.
- `CreateNamespace=true`: create `syncopts-lab` when necessary; not a namespace lifecycle controller.
- `PrunePropagationPolicy=foreground`: dependent resources cleaned up before owner deletion finishes.
- `PruneLast=true`: prune after successful rollout of remaining resources; this ConfigMap lab has no complex waves.
- `Replace=false`: do not use the potentially disruptive replace behavior.
- `ServerSideApply=true`: use managed fields; `Replace=true` would take precedence if enabled.
- `FailOnSharedResource=true`: refuse to sync a manifest already tracked by another Application.
- `RespectIgnoreDifferences=true`: honor ignoreDifferences rules during sync for **already existing** resources.

## The important distinction

`Synced`: desired and live state currently match after configured ignore rules.
`OutOfSync`: some live resource differs or is missing/extraneous.
`Automated enabled`: Argo CD attempts synchronization for eligible OutOfSync state.
`Automated disabled`: Argo CD reports OutOfSync but **does not sync by itself**.
`SelfHeal`: enables correction of live-only drift after a successful sync of the same revision.
`Prune`: allows removing previously managed resources removed from Git (with safeguards).

## Optional cleanup

```bash
# Deletes only the intentionally isolated syncopts-lab resources and Applications.
# Do this only after all tests are finished.
bash scripts/syncopts/90-cleanup.sh
```

Reference: https://argo-cd.readthedocs.io/en/release-3.5/user-guide/sync-options/
Reference: https://argo-cd.readthedocs.io/en/release-3.5/user-guide/auto_sync/
