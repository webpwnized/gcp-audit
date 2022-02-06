#!/bin/bash

declare SERVICE_ACCOUNT_EMAILS=$(gcloud iam service-accounts list --format="flattened(email)" | grep email | cut -d " " -f 2)

for SERVICE_ACCOUNT_EMAIL in $SERVICE_ACCOUNT_EMAILS; do
	echo "Service Account Keys for $SERVICE_ACCOUNT_EMAIL"
	echo ""
	gcloud iam service-accounts keys list --iam-account "$SERVICE_ACCOUNT_EMAIL" --format=json
	echo ""
done;
