#!/usr/bin/env bash
# Read-only preflight: warns if the repo's default GITHUB_TOKEN permissions could block
# the version-bump push, even though ios-release.yml declares `permissions: contents: write`.
set -euo pipefail

default_perm="$(gh api repos/:owner/:repo/actions/permissions/workflow -q .default_workflow_permissions 2>/dev/null || echo "unknown")"

case "$default_perm" in
  write)
    echo "  ok  default workflow permissions: write"
    ;;
  read)
    echo "WARNING: repo default workflow permissions are read-only." >&2
    echo "ios-release.yml declares 'permissions: contents: write', which normally overrides this," >&2
    echo "but an org-enforced policy can still block it. If the version-bump push fails with a 403," >&2
    echo "check Settings -> Actions -> General -> Workflow permissions." >&2
    ;;
  *)
    echo "Could not read workflow permission settings (needs repo admin access) — skipping check." >&2
    ;;
esac
