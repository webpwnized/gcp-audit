#!/bin/bash

source common-constants.inc;

declare SERVICE_ACCOUNTS=$(gcloud iam service-accounts list --format="flattened(email)" | grep email | cut -d " " -f 2)

for SERVICE_ACCOUNT in $SERVICE_ACCOUNTS; do
	echo "Service Account $SERVICE_ACCOUNT";
	echo $BLANK_LINE;
	 gcloud iam service-accounts keys list --iam-account=$SERVICE_ACCOUNT --managed-by=user;
	echo $BLANK_LINE;
	sleep $SLEEP_SECONDS;
done;
