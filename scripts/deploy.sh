#!/usr/bin/env bash
#
# Production deploy script. Runs only after a required reviewer works through the
# checklist and approves the `Prod` environment in GitHub Actions.
#
# Environment variables (set by the workflow):
#   GIT_SHA  Commit being deployed.
#   GIT_REF  Branch or tag name being deployed.
#
set -euo pipefail

echo "Deploying to production"
echo "  commit: ${GIT_SHA:-unknown}"
echo "  ref:    ${GIT_REF:-unknown}"

# ---------------------------------------------------------------------------
# Real deploy logic goes here. For example:
#   - build and push a container image tagged with ${GIT_SHA}
#   - apply infrastructure or Kubernetes manifests
#   - trigger your hosting provider's deploy API
#   - run post-deploy verification against the production URL
# ---------------------------------------------------------------------------

echo "Placeholder: no deploy performed."
