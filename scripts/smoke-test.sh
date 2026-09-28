#!/usr/bin/env bash
#
# Smoke tests run against the staging environment before a production deploy.
#
# Environment variables:
#   STAGING_URL        Base URL of the staging environment (required).
#   SMOKE_RESULTS_FILE Path to the markdown file that receives one table row per
#                      check. Defaults to smoke-results.md in the current dir.
#   GITHUB_OUTPUT      Set by GitHub Actions. When present, `failed=true` is
#                      written to it if any check fails.
#
# The script always exits 0 so the workflow can render the summary first; the
# workflow then fails the job based on the `failed` step output. Run locally
# with:  STAGING_URL=https://staging.example.com ./scripts/smoke-test.sh
#
set -u

STAGING_URL="${STAGING_URL:?STAGING_URL must be set}"
STAGING_URL="${STAGING_URL%/}" # strip trailing slash
SMOKE_RESULTS_FILE="${SMOKE_RESULTS_FILE:-smoke-results.md}"
CURL_OPTS=(--silent --show-error --fail --location --max-time 15 --output /dev/null)

any_failed=false
: > "${SMOKE_RESULTS_FILE}"

# check "<name>" "<command>"
#
# Runs <command> via bash. A zero exit status is recorded as PASS, anything
# else as FAIL. Each result is appended as a markdown table row to
# $SMOKE_RESULTS_FILE, and any failure marks the whole run as failed.
check() {
  local name="$1"
  local cmd="$2"
  local output status

  printf 'Running check: %s\n' "${name}"
  if output=$(bash -c "${cmd}" 2>&1); then
    status="PASS"
  else
    status="FAIL"
    any_failed=true
    printf '  FAILED: %s\n' "${output}"
  fi
  printf '  %s\n' "${status}"
  printf '| %s | %s |\n' "${name}" "${status}" >> "${SMOKE_RESULTS_FILE}"
}

# ---------------------------------------------------------------------------
# Checks
#
# Each check is a shell command that must exit 0 to pass. The placeholders below
# only verify that endpoints return a successful HTTP status. Replace or extend
# them with real assertions, for example:
#
#   check "Health reports ok" \
#     "curl ${CURL_OPTS[*]} --output - ${STAGING_URL}/health | grep -q '\"status\":\"ok\"'"
#   check "Version matches release" \
#     "test \"\$(curl -s ${STAGING_URL}/api/version | jq -r .version)\" = \"\${EXPECTED_VERSION}\""
#   check "Login page contains form" \
#     "curl -s ${STAGING_URL}/login | grep -q '<form'"
# ---------------------------------------------------------------------------

check "GET /health returns 2xx" \
  "curl ${CURL_OPTS[*]} ${STAGING_URL}/health"

check "GET /login returns 2xx" \
  "curl ${CURL_OPTS[*]} ${STAGING_URL}/login"

check "GET /api/version returns 2xx" \
  "curl ${CURL_OPTS[*]} ${STAGING_URL}/api/version"

# --- Add more checks above this line ---------------------------------------

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo
echo "Results written to ${SMOKE_RESULTS_FILE}:"
cat "${SMOKE_RESULTS_FILE}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "failed=${any_failed}" >> "${GITHUB_OUTPUT}"
fi

if [ "${any_failed}" = "true" ]; then
  echo
  echo "Smoke tests FAILED."
else
  echo
  echo "Smoke tests PASSED."
fi

# Exit 0 on purpose; the workflow fails the job from the `failed` step output
# after the summary has been written.
exit 0
