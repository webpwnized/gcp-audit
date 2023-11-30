#!/bin/bash

source common-constants.inc;
source functions.inc;

declare SEPARATOR="---------------------------------------------------------------------------------";
declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 			set -- "$@" "-h" ;;
    "--debug") 			set -- "$@" "-d" ;;
    "--csv") 			set -- "$@" "-c" ;;
    "--project")   		set -- "$@" "-p" ;;
    *)        			set -- "$@" "$arg"
  esac
done

while getopts "hdcp:" option
do 
    case "${option}"
        in
        p)
        	PROJECT_IDS=${OPTARG};;
        d)
        	DEBUG="True";;
        c)
        	CSV="True";;
        h)
        	echo $HELP; 
        	exit 0;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

if [[ $DEBUG == "True" ]]; then
	echo "Projects: $PROJECT_IDS";
fi;

if [[ $CSV == "True" ]]; then
	echo "\"PROJECT_ID\", \"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"BUCKET_NAME_SHORT\", \"BUCKET_NAME_LOCATION\", \"BUCKET_LIFECYCLE_STATE\", \"BUCKET_RETENTION_DAYS\", \"BUCKET_DESCRIPTION\", \"BUCKET_RETENTION_WARNING\"";
fi;

for PROJECT_ID in $PROJECT_IDS; do

	set_project $PROJECT_ID;

	if ! api_enabled logging.googleapis.com; then
		if [[ $CSV != "True" ]]; then
			echo "WARNING: Logging API is not enabled";
		fi;
		continue;
	fi;

	declare BUCKETS=$(gcloud logging buckets list --format json --project="$PROJECT_ID");
	
	if [[ $DEBUG == "True" ]]; then
		echo "Buckets (JSON): $BUCKETS";
	fi;

	if [[ $CSV != "True" ]]; then
		echo $SEPARATOR;
		echo "Log buckets for Project $PROJECT_ID";
		echo $SEPARATOR;
	fi;
	
	if [[ $BUCKETS != "[]" ]]; then

      		#Get project details
      		get_project_details $PROJECT_ID

		echo $BUCKETS | jq -rc '.[]' | while IFS='' read -r BUCKET;do
		
			if [[ $DEBUG == "True" ]]; then
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";			
				echo "Log Bucket (JSON): $BUCKET";
				echo $BLANK_LINE;
			fi;

			BUCKET_NAME=$(echo $BUCKET | jq -rc '.name');
			BUCKET_NAME_SHORT="$(echo $BUCKET_NAME | cut -d/ -f6)";
			BUCKET_LOCATION="$(echo $BUCKET_NAME | cut -d/ -f4)";
			BUCKET_DESCRIPTION=$(echo $BUCKET | jq -rc '.description');
			BUCKET_LIFECYCLE_STATE=$(echo $BUCKET | jq -rc '.lifecycleState');
			BUCKET_RETENTION_DAYS=$(echo $BUCKET | jq -rc '.retentionDays');
			BUCKET_RETENTION_WARNING="";

			if [[ $BUCKET_NAME_SHORT == "_Default" && $BUCKET_RETENTION_DAYS > 30 ]]; then
				BUCKET_RETENTION_WARNING="WARNING: _Default bucket retention policy exceeds 30 days. Costs may increase.";
			fi;

			# Print the results gathered above
			if [[ $CSV != "True" ]]; then
				echo "Project ID: $PROJECT_ID";
				echo "Project Name: $PROJECT_NAME";
				echo "Project Application: $PROJECT_APPLICATION";
				echo "Project Owner: $PROJECT_OWNER";
				echo "Log Bucket Name: $BUCKET_NAME_SHORT";
				echo "Log Bucket Location: $BUCKET_LOCATION";
				echo "Log Bucket Lifecycle State: $BUCKET_LIFECYCLE_STATE";
				echo "Log Bucket Retention Days: $BUCKET_RETENTION_DAYS";
				echo "Log Bucket Description: $BUCKET_DESCRIPTION";
				echo "Log Bucket Retention Information: $BUCKET_RETENTION_WARNING";
				echo $BLANK_LINE;
			else
				echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$BUCKET_NAME_SHORT\", \"$BUCKET_NAME_LOCATION\", \"$BUCKET_LIFECYCLE_STATE\", \"$BUCKET_RETENTION_DAYS\", \"$BUCKET_DESCRIPTION\", \"$BUCKET_RETENTION_WARNING\"";
			fi;		

		done;

	else
		if [[ $CSV != "True" ]]; then
			echo "No log buckets found for project $PROJECT_ID";
			echo $BLANK_LINE;
		fi;
	fi;
	sleep $SLEEP_SECONDS;
done;

