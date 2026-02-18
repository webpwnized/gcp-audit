#!/bin/bash
# CIS 4.10.1 - Check Cloud Run services ingress settings
source "$(dirname "$0")/common-constants.inc"
source "$(dirname "$0")/functions.inc"

echo "Checking Cloud Run services ingress settings..."
echo ""

for PROJECT in $(gcloud projects list --format="value(projectId)" 2>/dev/null); do
    SERVICES=$(gcloud run services list --project="$PROJECT" --format="value(metadata.name,status.url)" 2>/dev/null)
    while IFS= read -r SERVICE; do
        [ -z "$SERVICE" ] && continue
        NAME=$(echo "$SERVICE" | awk '{print $1}')
        INGRESS=$(gcloud run services describe "$NAME" --project="$PROJECT" --format="value(spec.template.metadata.annotations.'run.googleapis.com/ingress')" 2>/dev/null)
        if [ "$INGRESS" == "all" ] || [ -z "$INGRESS" ]; then
            echo "[WARN] $PROJECT/$NAME - Ingress: ${INGRESS:-all (default)}"
        else
            echo "[PASS] $PROJECT/$NAME - Ingress: $INGRESS"
        fi
    done <<< "$SERVICES"
done
echo ""
echo "Check complete."
