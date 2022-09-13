#!/bin/bash


api_enabled(){
    if [[ $(gcloud services list --enabled --filter="NAME=$1" | grep -c $1) -ge 1 ]]; then
        return 0
    else
        return 1
    fi
}