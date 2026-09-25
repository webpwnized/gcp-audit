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
    "--help")       set -- "$@" "-h" ;;
    "--debug")      set -- "$@" "-d" ;;
    "--project")    set -- "$@" "-p" ;;
    "--csv")        set -- "$@" "-c" ;;
    *)              set -- "$@" "$arg"
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
    echo '"PROJECT_ID", "SERVICE_NAME", "SERVICE_URL", "SERVICE_INGRESS_SETTING", "CONNECTION_STATUS", "HTTP_STATUS", "CONTENT_TYPE", "REDIRECT_URL", "PUBLIC_HOSTNAME", "PUBLIC_CONNECTION_STATUS", "PUBLIC_HTTP_STATUS", "PUBLIC_CONTENT_TYPE", "PUBLIC_REDIRECT_URL", "INGRESS_VIOLATION", "EXPOSED_URL_VIOLATION", "CERTIFICATE_VIOLATION", "AUTHENTICATION_STATUS", "AUTHENTICATION_VIOLATION", "ALL_VIOLATIONS"';
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

            # Reset Public Hostname Probe & Violation Variables
            PUBLIC_CONNECTION_STATUS="N/A";
            PUBLIC_HTTP_STATUS="N/A";
            PUBLIC_CONTENT_TYPE="N/A";
            FINAL_PUBLIC_URL="N/A";
            PUBLIC_BODY="";

            INGRESS_VIOLATION="N/A";
            EXPOSED_URL_VIOLATION="N/A";
            CERTIFICATE_VIOLATION="N/A";
            AUTHENTICATION_VIOLATION="N/A";
            AUTHENTICATION_STATUS="Unknown";
            VIOLATIONS=();

            if [[ $PUBLIC_HOSTNAME != "N/A" ]]; then
                # 1. Test TLS Certificate Validity (Strict SSL Check)
                curl --silent --output /dev/null --connect-timeout 5 --max-time 10 "https://$PUBLIC_HOSTNAME/"
                STRICT_CURL_EXIT=$?

                if [[ $STRICT_CURL_EXIT -eq 60 ]]; then
                    CERTIFICATE_VIOLATION="Public endpoint uses an untrusted/private CA certificate instead of a public CA cert"
                    VIOLATIONS+=("$CERTIFICATE_VIOLATION")
                fi

                # 2. Perform Content & Auth Probe (Bypassing SSL with -k so we can inspect the app)
                PUBLIC_HTTP_RESPONSE=$(curl \
                    --silent \
                    --insecure \
                    --location \
                    --connect-timeout 5 \
                    --max-time 15 \
                    --write-out "\n%{http_code}|%{content_type}|%{url_effective}" \
                    "https://$PUBLIC_HOSTNAME/");

                PUBLIC_CURL_EXIT_CODE=$?;

                if [[ $PUBLIC_CURL_EXIT_CODE -eq 0 ]]; then
                    PUBLIC_CONNECTION_STATUS="Connected";
                    PUBLIC_BODY=$(echo "$PUBLIC_HTTP_RESPONSE" | sed '$d')
                    METRICS=$(echo "$PUBLIC_HTTP_RESPONSE" | tail -n 1)
                    IFS='|' read -r PUBLIC_HTTP_STATUS PUBLIC_CONTENT_TYPE FINAL_PUBLIC_URL <<< "$METRICS";
                else
                    PUBLIC_CONNECTION_STATUS="Connection Failed";
                fi
            fi

            # --- VIOLATION EVALUATION LOGIC ---

            # 1. Ingress Violation Check
            if [[ $INGRESS_SETTING == "all" ]]; then
                INGRESS_VIOLATION="Ingress setting is ALL (Direct internet traffic permitted)"
                VIOLATIONS+=("$INGRESS_VIOLATION")
            fi

            # 2. Native Cloud Run URL Exposure Check
            if [[ $INGRESS_SETTING == "all" ]]; then
                if [[ $CONNECTION_STATUS == "Connected" ]]; then
                    if [[ $HTTP_STATUS =~ ^[23] ]] && [[ $REDIRECT_URL != *"login.microsoftonline.com"* && $REDIRECT_URL != *"auth0.com"* ]]; then
                        EXPOSED_URL_VIOLATION="Native Cloud Run URL ($SERVICE_URL) is publicly accessible"
                        VIOLATIONS+=("$EXPOSED_URL_VIOLATION")
                    fi
                fi
            fi

            # 3. Public Load Balancer Authentication Check
            if [[ $PUBLIC_HOSTNAME != "N/A" && $PUBLIC_CONNECTION_STATUS == "Connected" ]]; then
                if [[ $FINAL_PUBLIC_URL == *"login.microsoftonline.com"* ]]; then
                    AUTHENTICATION_STATUS="Microsoft Entra Auth Required"
                elif [[ $FINAL_PUBLIC_URL == *"auth0.com"* ]]; then
                    AUTHENTICATION_STATUS="Auth0 Auth Required"
                elif [[ $PUBLIC_HTTP_STATUS == "401" || $PUBLIC_HTTP_STATUS == "403" ]]; then
                    AUTHENTICATION_STATUS="Access Denied (Authenticated/Restricted)"
                elif [[ $FINAL_PUBLIC_URL == *"/login"* || $FINAL_PUBLIC_URL == *"/signin"* || $PUBLIC_BODY == *"<app-root>"* || $PUBLIC_BODY == *"Platform"* ]]; then
                    AUTHENTICATION_STATUS="Non-Compliant (Custom/Local Form Auth)"
                    AUTHENTICATION_VIOLATION="Public URL (https://$PUBLIC_HOSTNAME/) renders a custom local application/login page instead of federating through Entra or Auth0"
                    VIOLATIONS+=("$AUTHENTICATION_VIOLATION")
                elif [[ $PUBLIC_HTTP_STATUS == "200" ]]; then
                    AUTHENTICATION_STATUS="Unauthenticated / Public Access"
                    AUTHENTICATION_VIOLATION="Public URL (https://$PUBLIC_HOSTNAME/) does not enforce authentication"
                    VIOLATIONS+=("$AUTHENTICATION_VIOLATION")
                fi
            else
                if [[ $HTTP_STATUS == "200" && $REDIRECT_URL != *"login.microsoftonline.com"* && $REDIRECT_URL != *"auth0.com"* ]]; then
                    AUTHENTICATION_STATUS="Unauthenticated / Public Access"
                    AUTHENTICATION_VIOLATION="Service lacks a Load Balancer and does not enforce authentication"
                    VIOLATIONS+=("$AUTHENTICATION_VIOLATION")
                fi
            fi

            # Join all triggered violations into a single string
            ALL_VIOLATIONS="None"
            if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
                IFS="; "
                ALL_VIOLATIONS="${VIOLATIONS[*]}"
                unset IFS
            fi

            # --- OUTPUT RENDERING ---
            if [[ $CSV == "True" ]]; then
                echo "\"$PROJECT_ID\", \"$NAME\", \"$SERVICE_URL\", \"$INGRESS_SETTING\", \"$CONNECTION_STATUS\", \"$HTTP_STATUS\", \"$CONTENT_TYPE\", \"$REDIRECT_URL\", \"$PUBLIC_HOSTNAME\", \"$PUBLIC_CONNECTION_STATUS\", \"$PUBLIC_HTTP_STATUS\", \"$PUBLIC_CONTENT_TYPE\", \"$FINAL_PUBLIC_URL\", \"$INGRESS_VIOLATION\", \"$EXPOSED_URL_VIOLATION\", \"$CERTIFICATE_VIOLATION\", \"$AUTHENTICATION_STATUS\", \"$AUTHENTICATION_VIOLATION\", \"$ALL_VIOLATIONS\"";
            else
                echo "Project ID: $PROJECT_ID";
                echo "Service Name: $NAME";
                echo "Service URL: $SERVICE_URL";
                echo "Service Ingress Setting: $INGRESS_SETTING";
                echo "Direct Connection Status: $CONNECTION_STATUS";
                echo "Direct HTTP Status: $HTTP_STATUS";
                echo "Direct Content Type: $CONTENT_TYPE";
                echo "Direct Redirect URL: $REDIRECT_URL";
                echo "Public Hostname: $PUBLIC_HOSTNAME";
                echo "Public Connection Status: $PUBLIC_CONNECTION_STATUS";
                echo "Public HTTP Status: $PUBLIC_HTTP_STATUS";
                echo "Public Content Type: $PUBLIC_CONTENT_TYPE";
                echo "Public Redirect URL: $FINAL_PUBLIC_URL";

                if [[ $INGRESS_VIOLATION != "N/A" ]]; then
                    echo "Ingress Violation: $INGRESS_VIOLATION";
                fi

                if [[ $EXPOSED_URL_VIOLATION != "N/A" ]]; then
                    echo "Exposed URL Violation: $EXPOSED_URL_VIOLATION";
                fi

                if [[ $CERTIFICATE_VIOLATION != "N/A" ]]; then
                    echo "Certificate Violation: $CERTIFICATE_VIOLATION";
                fi

                echo "Authentication Status: $AUTHENTICATION_STATUS";

                if [[ $AUTHENTICATION_VIOLATION != "N/A" ]]; then
                    echo "Authentication Violation: $AUTHENTICATION_VIOLATION";
                fi

                echo "All Violations: $ALL_VIOLATIONS";
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