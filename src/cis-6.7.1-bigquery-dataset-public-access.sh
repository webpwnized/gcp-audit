#!/bin/bash
# CIS 6.7.1 - Check BigQuery datasets for public access
source "$(dirname "$0")/common-constants.inc"
source "$(dirname "$0")/functions.inc"

echo "Checking BigQuery datasets for public access..."
echo ""

for PROJECT in $(gcloud projects list --format="value(projectId)" 2>/dev/null); do
    DATASETS=$(gcloud bq ls --project_id="$PROJECT" --format="value(datasetReference.datasetId)" 2>/dev/null)
    for DATASET in $DATASETS; do
        ACCESS=$(bq show --format=json "$PROJECT:$DATASET" 2>/dev/null | jq -r '.access[]? | select(.specialGroup == "allAuthenticatedUsers" or .specialGroup == "allUsers")')
        if [ -n "$ACCESS" ]; then
            echo "[FAIL] $PROJECT:$DATASET - Public access enabled"
        fi
    done
done
echo ""
echo "Check complete."
