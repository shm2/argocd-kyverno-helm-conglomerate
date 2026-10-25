#!/usr/bin/env bash
set -euo pipefail

# Run this from the extracted project root, with an EMPTY remote repository
# already created in GitHub/GitLab. Example:
# bash scripts/05-publish-gitops.sh https://github.com/ACCOUNT/REPOSITORY.git

# Require exactly one real remote URL; never guess a GitHub username/repo.
if [[ $# -ne 1 || ! "$1" =~ ^https:// ]]; then
  echo 'Usage: bash scripts/05-publish-gitops.sh https://HOST/ACCOUNT/REPO.git' >&2
  exit 2
fi
REPO_URL="$1"

# Make sure commands are executed from this ZIP's project root.
if [[ ! -f charts/sts-web/Chart.yaml || ! -f argocd/apps/20-sts-web.yaml ]]; then
  echo 'ERROR: cd into kubeadm-sts-kyverno-gitops first.' >&2
  exit 2
fi

# Prevent silently overwriting any remote URLs somebody already customized.
if grep -q 'REPLACE_WITH_YOUR_GIT_REPOSITORY' argocd/apps/*.yaml; then
  # Only the Argo CD Application sources need the actual Git remote.
  sed -i "s|REPLACE_WITH_YOUR_GIT_REPOSITORY|${REPO_URL}|g" argocd/apps/*.yaml
fi

# Reject mixed/wrong repository URLs; both apps must follow THIS remote.
if [[ "$(grep -lF "repoURL: ${REPO_URL}" argocd/apps/*.yaml | wc -l)" -ne 2 ]]; then
  echo 'ERROR: Both Argo CD Applications must use the same supplied repo URL.' >&2
  exit 2
fi

# Keep this lab in its own Git repository. Avoid accidentally nesting repos.
if [[ -d .git ]]; then
  echo 'ERROR: This project already has .git. Inspect your remotes manually.' >&2
  exit 2
fi

# This requires a configured git user.name and user.email, plus push access.
git init -b main
git add .
git commit -m 'Bootstrap kubeadm StatefulSet and Kyverno GitOps lab'
git remote add origin "$REPO_URL"

# If authentication fails, use your configured Git credential manager/PAT/SSH.
# Do NOT paste access tokens into chat or commit them into manifests.
git push -u origin main

echo 'GitOps source published. Safe to run: bash scripts/15-deploy.sh'
