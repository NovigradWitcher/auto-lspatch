#!/usr/bin/env bash
set -euo pipefail

OWNER="JingMatrix"
REPO="LSPatch"
WORKFLOW_FILE="main.yml"

# Function: find latest successful workflow run with at least 1 artifact
get_latest_successful_run_with_artifact() {
    local run_json
    run_json=$(gh api "repos/$OWNER/$REPO/actions/workflows/$WORKFLOW_FILE/runs?per_page=10")

    for row in $(echo "$run_json" | jq -r '.workflow_runs[] | @base64'); do
        _jq() { echo "$row" | base64 --decode | jq -r "$1"; }
        local run_id=$(_jq '.id')
        local conclusion=$(_jq '.conclusion')

        # Only success runs
        if [ "$conclusion" != "success" ]; then
            continue
        fi

        # Check artifact count
        local artifact_count
        artifact_count=$(gh api repos/$OWNER/$REPO/actions/runs/$run_id/artifacts | jq '.artifacts | length')
        if [ "$artifact_count" -ge 1 ]; then
            echo "$run_id"
            return
        fi
    done

    echo ""
}

# --- Latest release info
REL_DATE=""
if gh api repos/$OWNER/$REPO/releases/latest > release.json 2>/dev/null; then
    REL_DATE=$(jq -r '.published_at' release.json)
fi

# --- Latest workflow info
RUN_ID=$(get_latest_successful_run_with_artifact)
WORKFLOW_DATE=""
if [ -n "$RUN_ID" ]; then
    WORKFLOW_DATE=$(gh api "repos/$OWNER/$REPO/actions/runs/$RUN_ID" -q '.updated_at')
fi

# --- Decide which source
if [ -n "$REL_DATE" ] && { [ -z "$WORKFLOW_DATE" ] || [ "$(date -d "$REL_DATE" +%s)" -gt "$(date -d "$WORKFLOW_DATE" +%s)" ]; }; then
    echo "release"
elif [ -n "$RUN_ID" ]; then
    echo "artifact"
else
    echo "none"
fi
