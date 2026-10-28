# Argo CD 3.5 — Sync Hooks & Waves GitOps lab

This ADD-ON belongs inside your existing local Git repository `~/kubeadm-sts-kyverno-gitops`.
No new GitHub repository; no replacement of existing Argo CD, MySQL, Redis, `sts-web` or Kyverno components.

## 1. Import into existing Git repo, push, bootstrap

```bash
# Select the three-node kubeadm cluster.
export KUBECONFIG="$HOME/.kube/k8scp2-admin.conf"

# Enter the existing GitOps working tree before extracting the add-on.
cd ~/kubeadm-sts-kyverno-gitops
unzip -o ~/argocd-hooks-waves-addon.zip

# Create the isolated namespace BEFORE the PreSync Job runs.
kubectl create namespace hooks-lab --dry-run=client -o yaml | kubectl apply -f -

# Check the correct Git repository URL in the new Application.
grep -n 'repoURL:' argocd/apps/40-hooks-lab.yaml

# Commit this lab alongside your existing charts and policies.
git add argocd/apps/40-hooks-lab.yaml labs/hooks scripts/hooks LAB-HOOKS-START-HERE.md
git commit -m 'Add Argo CD sync hooks and waves lab'
git push origin main

# Register this new Application without touching the others.
kubectl apply -f argocd/apps/40-hooks-lab.yaml

# Monitor sync and its resources.
watch -n 3 'kubectl -n argocd get application hooks-lab; kubectl -n hooks-lab get jobs,deploy,pods,svc'
```

## 2. Verify the SUCCESS path

```bash
# Display current sync status and hook Jobs/logs.
bash scripts/hooks/00-verify.sh

# Verify that the ConfigMap-backed website responds through its Service.
kubectl -n hooks-lab run hooks-client --image=busybox:1.36 --restart=Never --rm -i \
  -- wget -qO- http://hooks-demo:8080/
```

Expected: `PRESYNC_PASS`, `SYNC_WAVE_2_PASS`, `POSTSYNC_PASS`; Application `Synced / Healthy`; Deployment `1/1`. The optional `kubectl run --rm -i` request removes the disposable client Pod afterward.

## 3. Controlled failure experiment — demonstration of SyncFail

Do this only after the success path works. Do not change the live resources with kubectl; edit Git.

```bash
# Make PreSync deliberately fail its readiness gate.
sed -i 's/value: "yes"/value: "no"/' labs/hooks/resources/10-presync.yaml

# Change ordinary desired state too, ensuring auto-sync has real drift.
sed -i 's/SYNC_WAVES_WORK/SYNC_WAVES_WORK_V2/' labs/hooks/resources/20-page-configmap.yaml

# Commit/push only the lab changes.
git add labs/hooks/resources/10-presync.yaml labs/hooks/resources/20-page-configmap.yaml
git commit -m 'Lab: intentionally fail PreSync to trigger SyncFail'
git push origin main

# Watch operation failure and inspect the failing PreSync Job plus SyncFail Job.
watch -n 3 'kubectl -n argocd get app hooks-lab; kubectl -n hooks-lab get jobs'
```

Once failed, run:

```bash
# Read preflight failure (expected exit 42).
kubectl -n hooks-lab logs job/hooks-preflight --tail=30

# Confirm the SyncFail hook executed.
kubectl -n hooks-lab logs job/hooks-on-failure --tail=30
```

Expect `PRESYNC_DENIED`, `SYNCFAIL_TRIGGERED`, and Argo CD operation `Failed`. PreSync failure stops the Sync and PostSync phases.

## 4. Restore success WITHOUT deleting Pods, PVCs, or other Applications

```bash
# Re-enable PreSync and make a NEW ordinary desired-state change.
sed -i 's/value: "no"/value: "yes"/' labs/hooks/resources/10-presync.yaml
sed -i 's/SYNC_WAVES_WORK_V2/SYNC_WAVES_WORK_V3/' labs/hooks/resources/20-page-configmap.yaml

# Publish a distinct Git revision so auto-sync can retry.
git add labs/hooks/resources/10-presync.yaml labs/hooks/resources/20-page-configmap.yaml
git commit -m 'Lab: restore passing PreSync and resume hooks'
git push origin main

# Inspect recovery (may require a hard refresh to detect commit promptly).
kubectl -n argocd annotate application hooks-lab argocd.argoproj.io/refresh=hard --overwrite
bash scripts/hooks/00-verify.sh
```

## 5. Hook deletion behavior

`hooks-preflight`, `hooks-sync-check`, `hooks-smoke-test`, and `hooks-on-failure` use `BeforeHookCreation` to retain Job logs until the next run. `hooks-postdelete` uses `HookSucceeded` for auto-cleanup.

`PostDelete` is NOT an ordinary sync hook. It is triggered after cascading Application deletion. Do not delete this Application unless you are finished with the lab; do not delete the entire namespace because that would prevent the cleanup Job from running.

To inspect it during optional *final* cleanup, delete ONLY this Application with cascading deletion from the Argo CD UI. The `hooks-lab` namespace is separate from the Application and remains intact. Then inspect namespace events or the Argo CD deletion operation (the PostDelete Job may disappear promptly due to `HookSucceeded`).

## Interview considerations

- Phases sort before waves; use negative waves for prerequisites.
- PreSync can only read Secrets/ConfigMaps already present before this sync, unless they are themselves earlier hooks.
- Hook Jobs should be idempotent; they may run again on subsequent full syncs.
- `metadata.name` + `BeforeHookCreation` gives repeated named Jobs; `generateName` gives unique Job names.
- Selective Sync skips hooks, but `ApplyOutOfSyncOnly=true` on a full sync does not skip them.
- Failed syncs and PostSync hook failures do not automatically roll back a Deployment.

References:
- https://argo-cd.readthedocs.io/en/release-3.5/user-guide/sync-waves/
- https://argo-cd.readthedocs.io/en/release-3.5/user-guide/resource_hooks/
- https://argo-cd.readthedocs.io/en/release-3.5/user-guide/selective_sync/
