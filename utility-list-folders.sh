#!/bin/bash

if [ $# -eq 0 ]; then
	echo "Usage: $0 ORGANIZATION_ID"
	exit
fi

ORGANIZATION_ID=$1

gcloud resource-manager folders list --organization $ORGANIZATION_ID
