# Deployment pipeline with manual approval

This repository contains a GitHub Actions pipeline that presents a reviewer
with a sign-off checklist and then waits for that reviewer to approve the
production deploy.

## What the pipeline does

The workflow lives in [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)
and runs on every push to `main`, or manually via **Actions → Deploy → Run
workflow**.

```
push to main / workflow_dispatch
          │
          ▼
   ┌──────────────────────┐   writes .github/deploy-checklist.md
   │ pre-deploy-checklist │   to the run's Summary tab
   └──────────────────────┘
          │
          ▼
   ┌──────────────────────┐   waits for a required reviewer on the
   │     deploy-prod      │   `Prod` environment, then runs
   └──────────────────────┘   scripts/deploy.sh
```

1. **`pre-deploy-checklist`** checks out the repo and writes the contents of
   [`.github/deploy-checklist.md`](.github/deploy-checklist.md) to the job
   summary, along with the commit, ref, who triggered the run, and the staging
   URL. Nothing is executed against staging; the checklist is for a human to
   work through.
2. **`deploy-prod`** depends on that job and targets the `Prod` environment.
   Because that environment has required reviewers, GitHub pauses the run here
   until someone approves it. Once approved, the job runs
   [`scripts/deploy.sh`](scripts/deploy.sh).

Only one deploy runs at a time (`concurrency: deploy-production`). Runs that
are already waiting at the gate are not cancelled by newer pushes.

### Files

| File | Purpose |
|------|---------|
| `.github/workflows/deploy.yml` | The two-job pipeline described above. |
| `.github/deploy-checklist.md` | The sign-off checklist shown to reviewers. Edit this to change what they must confirm. |
| `scripts/deploy.sh` | Placeholder deploy script. Replace the marked section with real deploy logic. |

### Editing the checklist

The checklist is plain markdown in `.github/deploy-checklist.md`. Add, remove
or reword items there; the workflow renders the file as-is. Keep each item as a
`- [ ]` line so it shows as a checkbox in the summary. The checklist can mix
manual smoke tests, product sign-off, comms, and anything else that has to be
true before production changes.

### Setting the staging URL

Go to **Settings → Secrets and variables → Actions → Variables** and add a
repository variable named `STAGING_URL`. It is shown in the summary so the
reviewer has a link to the environment they are checking. Without it, the
workflow falls back to `https://staging.example.com`.

## Creating the `Prod` environment

The approval gate only exists if the `Prod` environment has at least one
required reviewer. Until it is configured, `deploy-prod` runs immediately after
the checklist job with no pause.

### Via the GitHub UI

1. Open the repository and go to **Settings → Environments**.
2. Click **New environment**, name it `Prod`, and click **Configure
   environment**.
3. Under **Deployment protection rules**, tick **Required reviewers** and add
   up to six users or teams. Anyone listed can approve a run.
4. Optionally tick **Prevent self-review** so the person who pushed cannot
   approve their own deploy.
5. Optionally restrict **Deployment branches and tags** to `main` so the
   environment can only be deployed from the main branch.
6. Click **Save protection rules**.

**Plan limits:** deployment protection rules, including required reviewers,
are available on public repositories for every plan. On **private
repositories** they require GitHub Pro (for user-owned repos), Team, or
Enterprise. On a private repo under a Free plan the environment can be created
but the required-reviewers rule is not offered, so the gate will not pause the
run.

### Via the `gh` CLI

The same setup with the GitHub API. Replace `OWNER/REPO` and `REVIEWER`.

```bash
# Look up the numeric ID of the reviewer (a user).
REVIEWER_ID=$(gh api users/REVIEWER --jq .id)

# Create (or update) the environment with a required reviewer.
gh api --method PUT repos/OWNER/REPO/environments/Prod \
  --input - <<EOF_JSON
{
  "reviewers": [
    { "type": "User", "id": ${REVIEWER_ID} }
  ],
  "prevent_self_review": true,
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF_JSON

# With custom_branch_policies enabled, allow deploys from main.
gh api --method POST \
  repos/OWNER/REPO/environments/Prod/deployment-branch-policies \
  -f name=main -f type=branch
```

To add a team instead of a user, look up its ID with
`gh api orgs/ORG/teams/TEAM-SLUG --jq .id` and use `"type": "Team"` in the
`reviewers` list. The `PUT` call replaces the whole reviewer list, so include
every reviewer each time you run it. Drop the `deployment_branch_policy` block
and the second command if you do not want to restrict branches.

Verify the result:

```bash
gh api repos/OWNER/REPO/environments/Prod --jq '.protection_rules'
```

## Approving a deploy

When a run reaches `deploy-prod`, GitHub emails and notifies the required
reviewers and the run shows **Waiting** on the Actions page.

1. Open the run under **Actions → Deploy** and click the **Summary** tab.
2. Read the **Production deploy: reviewer checklist** section. It names the
   commit and ref being deployed and links to staging.
3. Work through every checklist item against staging. The checkboxes in the
   summary are a reading aid and cannot be ticked there; treat them as things
   to confirm before approving.
4. Click **Review deployments** at the top of the run, tick `Prod`, note in the
   comment which items you verified, and choose **Approve and deploy** or
   **Reject**.

Approving starts `deploy-prod`, which runs `scripts/deploy.sh`. Rejecting
fails the run without deploying. Pending approvals expire after 30 days.
