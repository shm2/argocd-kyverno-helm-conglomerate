# START HERE — StatefulSet + Kyverno GitOps on k8scp2

This package works with the existing kubeadm cluster (k8scp2, k8s-w1,
k8s-w2), Argo CD HA, Kyverno v1.19.1 installed via Helm, and NFS CSI
StorageClass `nfs-argocd`. It does **not** install Kyverno again.

**Required external prerequisite:** An *empty Git repository* you own that
Argo CD can read, for example `https://github.com/ACCOUNT/REPO.git`.
Create it in GitHub/GitLab first, and leave it empty (no README or license).
Use a public repo for the easiest Argo CD read access; for a private repo,
configure credentials in Argo CD Settings > Repositories. Never commit secrets.

## Windows PowerShell — move the ZIP to your Ubuntu VM

Assuming this downloaded ZIP is in your Windows Downloads folder:

```powershell
# Move the complete lab archive to k8scp2 over SSH.
scp "$env:USERPROFILE\Downloads\kubeadm-sts-kyverno-gitops-ready.zip" eirizarry@192.168.217.128:~/
```

## Ubuntu k8scp2 — extract and validate

```bash
# Extract the full repository tree, then enter its root.
cd ~
unzip -oq kubeadm-sts-kyverno-gitops-ready.zip
cd ~/kubeadm-sts-kyverno-gitops

# Verify the two Application manifests exist in THIS directory.
ls -l argocd/apps/

# Check environment (Kyverno, NFS class, nodes).
bash scripts/00-preflight.sh

# Render and lint the bundled Helm chart without deploying it.
helm lint charts/sts-web
```

## Publish real GitOps source

```bash
# Set your Git identity on k8scp2 if not already configured.
# git config --global user.name 'Your Name'
# git config --global user.email 'you@example.com'

# Replace URL with the remote EMPTY repo you actually created and own.
# This script sets both repoURLs, commits project files, and pushes main.
bash scripts/05-publish-gitops.sh https://github.com/ACCOUNT/REPO.git
```

If `git push` fails from missing credentials, fix Git authentication then
retry `git push -u origin main`; no need to redo `git init` or sed.
If the repository is private, add its credentials in Argo CD too.

## Deploy to kubeadm with Argo CD

```bash
# Both Argo CD Applications are auto-sync-enabled.
# Registers policies first and waits for sync, THEN the Helm-based StatefulSet.
bash scripts/15-deploy.sh

# Monitor ONLY the lab resources. Three 1-GiB claims should become Bound.
watch -n 2 'kubectl -n sts-lab get sts,pods,svc,pvc'
```

Expected names:

- Applications in `argocd`: `sts-lab-policies`, `sts-web`
- Namespace `sts-lab`
- StatefulSet `sts-web`, Pods `sts-web-0`, `sts-web-1`, `sts-web-2`
- PVCs `data-sts-web-0`, `data-sts-web-1`, `data-sts-web-2`
- Headless Service `sts-web-headless`, ClusterIP Service `sts-web`
- CEL policies `sts-lab-max-replicas`, `sts-lab-pod-owner`

## Test AFTER the workloads are Ready

```bash
# Verify 3/3 Pods and inspect namespace-scoped Kyverno policies.
bash scripts/20-verify.sh

# Test Kyverno Deny (replica budget), and Audit (missing Pod label).
bash scripts/30-test-kyverno.sh

# Test stable StatefulSet identity + NFS persistence across Pod recreation.
bash scripts/40-persistence-test.sh
```

For the Audit→Deny Git change and the partitioned rollout, see `README.md`.

### Boundaries and safety

- Don't apply the standalone Helm chart with `helm install`; Argo CD owns it.
- Don't reinstall `kyverno`, `argocd`, or `csi-driver-nfs`.
- `sts-lab` is isolated; this doesn't target Redis/MySQL or the other apps.
- The new NFS PVs use `Retain`; deleting a PVC/namespace doesn't guarantee
  removal of data on `/srv/nfs/argocd`.
- All scripts use `bash` and have comments; scripts are executable in this ZIP.
