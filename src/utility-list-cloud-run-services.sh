#!/bin/bash

source common-constants.inc;
source functions.inc

PROJECT_IDS="";
DEBUG="False";
CSV="False";
HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-d, --debug] [-c, --csv] [-h, --help]	
EOL
);

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") 		set -- "$@" "-h" ;;
    "--debug") 		set -- "$@" "-d" ;;
    "--project")   	set -- "$@" "-p" ;;
    "--csv")   	    set -- "$@" "-c" ;;
    *)        		set -- "$@" "$arg"
  esac
done

while getopts "hcdp:" option
do 
    case "${option}"
        in
        p) PROJECT_IDS=${OPTARG} ;;
        d) DEBUG="True" ;;
        c) CSV="True" ;;
        h) echo $HELP; exit 0 ;;
    esac;
done;

if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi;

# Print CSV header if CSV output is enabled
if [[ $CSV == "True" ]]; then
	echo '"PROJECT_ID", "SERVICE_NAME", "SERVICE_URL", "SERVICE_INGRESS_SETTING", "CONNECTION_STATUS", "HTTP_STATUS", "CONTENT_TYPE", "REDIRECT_URL", "INGRESS_VIOLATION", "AUTHENTICATION_STATUS", "AUTHENTICATION_VIOLATION"';
fi

for PROJECT_ID in $PROJECT_IDS; do	
	set_project $PROJECT_ID;
    
    # Check if Cloud Run API is enabled for the project
    if ! api_enabled run.googleapis.com; then
        if [[ $CSV != "True" ]]; then
            echo "Cloud Run API is not enabled for Project $PROJECT_ID.";
            echo ""
        fi
        continue
    fi

	declare SERVICES=$(gcloud run services list --quiet --format="json");
	GCLOUD_EXIT_CODE=$?;

	if [[ $GCLOUD_EXIT_CODE -ne 0 ]]; then
		echo "Error: Unable to enumerate Cloud Run services for Project $PROJECT_ID." >&2;
		continue;
	fi

	if [[ $SERVICES != "[]" ]]; then
	    if [[ $CSV != "True" ]]; then
	    	echo "---------------------------------------------------------------------------------";
	    	echo "Cloud Run Services for Project $PROJECT_ID";
	    	echo "---------------------------------------------------------------------------------";
	    fi
	
		echo "$SERVICES" | jq -rc '.[]' | while IFS='' read -r SERVICE; do
			NAME=$(echo "$SERVICE" | jq -rc '.metadata.name');
			SERVICE_URL=$(echo "$SERVICE" | jq -rc '.status.url');
			INGRESS_SETTING=$(echo "$SERVICE" | jq -rc '.metadata.annotations."run.googleapis.com/ingress"');

			SERVERLESS_NEG=$(gcloud compute network-endpoint-groups list \
				--project "$PROJECT_ID" \
				--filter="networkEndpointType=SERVERLESS" \
				--format=json 2>/dev/null \
				| jq -r --arg SERVICE_NAME "$NAME" \
					'.[] |
					select(.cloudRun.service == $SERVICE_NAME) |
					.name' \
				| head -n 1);

			if [[ -z "$SERVERLESS_NEG" ]]; then
				SERVERLESS_NEG="N/A";
			fi

			BACKEND_SERVICE="N/A";

			if [[ $SERVERLESS_NEG != "N/A" ]]; then
				BACKEND_SERVICE=$(gcloud compute backend-services list \
					--project "$PROJECT_ID" \
					--format=json 2>/dev/null \
					| jq -r --arg NEG "$SERVERLESS_NEG" \
						'.[] |
						select(any(.backends[]?; .group | contains("/networkEndpointGroups/" + $NEG))) |
						.name' \
					| head -n 1);

				if [[ -z "$BACKEND_SERVICE" ]]; then
					BACKEND_SERVICE="N/A";
				fi
			fi

			URL_MAP="N/A";

			if [[ $BACKEND_SERVICE != "N/A" ]]; then
				URL_MAP=$(gcloud compute url-maps list \
					--project "$PROJECT_ID" \
					--format=json 2>/dev/null \
					| jq -r --arg BACKEND "$BACKEND_SERVICE" \
						'.[] |
						select(tostring | contains("/backendServices/" + $BACKEND)) |
						.name' \
					| head -n 1);

				if [[ -z "$URL_MAP" ]]; then
					URL_MAP="N/A";
				fi
			fi

			PUBLIC_HOSTNAME="N/A";

			if [[ $URL_MAP != "N/A" ]]; then
				PUBLIC_HOSTNAME=$(gcloud compute url-maps describe "$URL_MAP" \
					--project "$PROJECT_ID" \
					--global \
					--format=json 2>/dev/null \
					| jq -r '.hostRules[]?.hosts[]?' \
					| grep -v '^\*$' \
					| head -n 1);

				if [[ -z "$PUBLIC_HOSTNAME" ]]; then
					PUBLIC_HOSTNAME="N/A";
				fi
			fi

			HTTP_RESPONSE=$(curl \
				--silent \
				--output /dev/null \
				--connect-timeout 5 \
				--max-time 15 \
				--write-out "%{http_code}|%{content_type}|%{redirect_url}" \
				"$SERVICE_URL");

			CURL_EXIT_CODE=$?;

			if [[ $CURL_EXIT_CODE -eq 0 ]]; then
				CONNECTION_STATUS="Connected";
				IFS='|' read -r HTTP_STATUS CONTENT_TYPE REDIRECT_URL <<< "$HTTP_RESPONSE";
			else
				CONNECTION_STATUS="Connection Failed";
				HTTP_STATUS="N/A";
				CONTENT_TYPE="N/A";
				REDIRECT_URL="N/A";
			fi

			PUBLIC_CONNECTION_STATUS="N/A";
			PUBLIC_HTTP_STATUS="N/A";
			PUBLIC_CONTENT_TYPE="N/A";
			PUBLIC_REDIRECT_URL="N/A";

			if [[ $PUBLIC_HOSTNAME != "N/A" ]]; then
				PUBLIC_HTTP_RESPONSE=$(curl \
					--silent \
					--output /dev/null \
					--connect-timeout 5 \
					--max-time 15 \
					--write-out "%{http_code}|%{content_type}|%{redirect_url}" \
					"https://$PUBLIC_HOSTNAME/");

				PUBLIC_CURL_EXIT_CODE=$?;

				if [[ $PUBLIC_CURL_EXIT_CODE -eq 0 ]]; then
					PUBLIC_CONNECTION_STATUS="Connected";
					IFS='|' read -r PUBLIC_HTTP_STATUS PUBLIC_CONTENT_TYPE PUBLIC_REDIRECT_URL <<< "$PUBLIC_HTTP_RESPONSE";
				else
					PUBLIC_CONNECTION_STATUS="Connection Failed";
				fi
			fi

# delete this block
if [[ $PUBLIC_HOSTNAME != "N/A" ]]; then
	echo "NAME=$NAME" >&2
	echo "PUBLIC_HOSTNAME=$PUBLIC_HOSTNAME" >&2
	echo "PUBLIC_HTTP_STATUS=$PUBLIC_HTTP_STATUS" >&2
	echo "PUBLIC_REDIRECT_URL=$PUBLIC_REDIRECT_URL" >&2
	echo "" >&2
fi

			if [[ $CSV == "True" ]]; then
				INGRESS_VIOLATION="N/A";
				AUTHENTICATION_STATUS="Unknown";
				AUTHENTICATION_VIOLATION="N/A";

				if [[ $INGRESS_SETTING == "all" ]]; then
					INGRESS_VIOLATION="The ingress setting is configured to ALL, which allows all requests including requests directly from the internet";
				fi

				if [[ $HTTP_STATUS == "401" || $HTTP_STATUS == "403" ]]; then
					AUTHENTICATION_STATUS="Unauthenticated Request Denied";
				fi

				if [[ $REDIRECT_URL == *"login.microsoftonline.com"* ]]; then
  				  AUTHENTICATION_STATUS="Microsoft Entra Authentication Redirect";
				fi

				echo "\"$PROJECT_ID\", \"$NAME\", \"$SERVICE_URL\", \"$INGRESS_SETTING\", \"$CONNECTION_STATUS\", \"$HTTP_STATUS\", \"$CONTENT_TYPE\", \"$REDIRECT_URL\", \"$INGRESS_VIOLATION\", \"$AUTHENTICATION_STATUS\", \"$AUTHENTICATION_VIOLATION\"";
			else
			    echo "Service Name: $NAME";
				echo "Service URL: $SERVICE_URL";
				echo "Service Ingress Setting: $INGRESS_SETTING";
			    
			    if [[ $INGRESS_SETTING == "all" ]]; then
			        echo "Violation: The ingress setting is configured to ALL, which allows all requests including requests directly from the internet";
			    fi
			    echo $BLANK_LINE;
			fi
			
		done;

		if [[ $CSV != "True" ]]; then
			echo $BLANK_LINE;
		fi

	else
	    if [[ $CSV != "True" ]]; then
	    	echo "No Cloud Run Services found for Project $PROJECT_ID";
	    	echo $BLANK_LINE;
	    fi
	fi;

	sleep $SLEEP_SECONDS;
done;

