#!/bin/bash

LONG=project:
SHORT=p:
OPTS=$(getopt -a -n testscript --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"
while :
do
    case "$1" in --project | -p )
        declare PROJECT_IDS="$2"
        shift 2
     ;;
     -- )
        shift;
        break
        ;;
        *)
        exit 2
    esac
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(gcloud projects list --format="flattened(PROJECT_ID)" | grep project_id | cut -d " " -f 2);
fi;

for PROJECT_ID in $PROJECT_IDS; do	
	gcloud config set project $PROJECT_ID;
	declare INSTANCES=$(gcloud compute instances list --quiet --format="json");

	if [[ $INSTANCES != "[]" ]]; then

		PROJECT_DETAILS=$(gcloud projects describe $PROJECT_ID --format="json");
		PROJECT_NAME=$(echo $PROJECT_DETAILS | jq -rc '.name');
		PROJECT_APPLICATION=$(echo $PROJECT_DETAILS | jq -rc '.labels.app');
		PROJECT_OWNER=$(echo $PROJECT_DETAILS | jq -rc '.labels.adid');
		
		echo "---------------------------------------------------------------------------------";
		echo "Instances for Project $PROJECT_ID";
		echo "---------------------------------------------------------------------------------";

		echo $INSTANCES | jq -rc '.[]' | while IFS='' read -r INSTANCE;do

			NAME=$(echo $INSTANCE | jq -rc '.name');			
			EXTERNAL_NETWORK_INTERFACES=$(echo $INSTANCE | jq -rc '.networkInterfaces' | jq 'select("accessConfigs")');
			IS_GKE_NODE=$(echo $INSTANCE | jq '.labels' | jq 'has("goog-gke-node")');
			
			if [[ $IS_GKE_NODE == "false" ]]; then
			
				echo $EXTERNAL_NETWORK_INTERFACES | jq -rc '.[]' | while IFS='' read -r INTERFACE;do

					INTERFACE_NAME=$(echo $INTERFACE | jq -rc '.name');
					NAT_IP=$(echo $INTERFACE | jq -rc '.accessConfigs[].natIP');
					
					if [[ $NAT_IP != "" ]]; then
						echo "Project Name: $PROJECT_NAME";
						echo "Project Application: $PROJECT_APPLICATION";
						echo "Project Owner: $PROJECT_OWNER";
						echo "Instance Name: $NAME";
						echo "Interface Name: $INTERFACE_NAME";
						echo "IP Address: $NAT_IP";
						echo "VIOLATION: Exterally routable IP address detected";
						echo "";
					else
						echo "Skipping interface with no external IP address";
					fi;
				done;
			else
				echo "Skipping GKE node $NAME";
			fi;
		done;
		echo "";
	else
		echo "No instances found for Project $PROJECT_ID";
		echo "";
	fi;
	sleep 0.5;
done;

