#!/bin/bash

gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2
