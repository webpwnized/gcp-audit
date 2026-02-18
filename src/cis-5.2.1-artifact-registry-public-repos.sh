#!/bin/bash
# CIS 5.2.1 - Check Artifact Registry for public repositories
source "$(dirname "$0")/common-constants.inc"
source "$(dirname "$0")/functions.inc"

echo "Checking Artifact Registry for public repositories..."
echo ""

for PROJECT in $(gcloud projects list --format="value(projectId)" 2>/dev/null); do
    REPOS=$(gcloud artifacts repositories list --project="$PROJECT" --format="value(name)" 2>/dev/null)
    for REPO in $REPOS; do
        IAM=$(gcloud artifacts repositories get-iam-policy "$REPO" --project="$PROJECT" --format=json 2>/dev/null)
        PUBLIC=$(echo "$IAM" | jq -r '.bindings[]? | select(.members[]? | contains("allUsers") or contains("allAuthenticatedUsers"))')
        if [ -n "$PUBLIC" ]; then
            echo "[FAIL] $PROJECT/$REPO - Public access enabled"
        fi
    done
done
echo ""
echo "Check complete."
