#!/bin/bash

source common-constants.inc;
source functions.inc;

declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";

declare HELP=$(cat << EOL
	$0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]	
EOL
)

for arg in "$@"; do
  shift
  case "$arg" in
    "--help")         set -- "$@" "-h" ;;
    "--debug")        set -- "$@" "-d" ;;
    "--csv")          set -- "$@" "-c" ;;
    "--project")      set -- "$@" "-p" ;;
    *)                set -- "$@" "$arg"
  esac
done

while getopts "hdcp:r:" option
do 
    case "${option}"
        in
        p)
            PROJECT_IDS=${OPTARG} ;;
        d)
            DEBUG="True" ;;
        c)
            CSV="True" ;;
        h)
            echo "$HELP"
            exit 0 ;;
    esac
done

if [[ $PROJECT_IDS == "" ]]; then
    PROJECT_IDS=$(get_projects)
fi

if [[ $CSV == "True" ]]; then
    echo "\"PROJECT_NAME\", \"PROJECT_OWNER\", \"PROJECT_APPLICATION\", \"VPC_NAME\", \"DNS_POLICY_NAME\", \"DNS_POLICY_ENABLED\", \"DNS_POLICY_LOGGING_ENABLED\", \"STATUS_MESSAGE\""
fi


for PROJECT_ID in $PROJECT_IDS; do
    set_project $PROJECT_ID

    if ! api_enabled compute.googleapis.com; then
        echo "Compute Engine API is not enabled on Project $PROJECT_ID"
        continue
    fi


    VPCS=$(gcloud compute networks list --format json)

    if [[ $CSV != "True" ]]; then
        echo "---------------------------------------------------------------------------------"
        echo "VPCs for Project $PROJECT_ID"
        echo $BLANK_LINE;
    fi

    if [[ $VPCS != "[]" ]]; then

      	#Get project details
      	get_project_details $PROJECT_ID


        echo $VPCS | jq -rc '.[]' | while IFS='' read -r VPC; do
            VPC_NAME=$(echo $VPC | jq -rc '.name')

            DNS_POLICIES=$(gcloud dns policies list --format json --project $PROJECT_ID)
            if [[ $DNS_POLICIES != "[]" ]]; then
                echo "${DNS_POLICIES}" | jq -rc '.[]' | while IFS='' read -r POLICY; do
                    POLICY_NETWORK=$(echo "$POLICY" | jq -r '.networks[] | select(.networkUrl | contains("'$VPC_NAME'"))')
                    if [[ $POLICY_NETWORK ]]; then
                        DNS_POLICY_NAME=$(echo "$POLICY" | jq -r '.name')
                        DNS_POLICY_ENABLED="true"
                        DNS_POLICY_LOGGING_ENABLED=$(echo "$POLICY" | jq -r '.enableLogging')
                        if [[ $DNS_POLICY_LOGGING_ENABLED == "false" ]]; then
                            STATUS_MESSAGE="VIOLATION: DNS policy logging is not enabled"
                        else
                            STATUS_MESSAGE="DNS policy logging is enabled"
                        fi

                        if [[ $DEBUG == "True" ]]; then
                            echo "DEBUG: VPC Name: $VPC_NAME"
                            echo "DEBUG: DNS Policy: $POLICY"
                        fi

                        # Print the results gathered above
                        if [[ $CSV != "True" ]]; then
                            echo "Project Name: $PROJECT_NAME"
                            echo "Project Application: $PROJECT_APPLICATION"
                            echo "Project Owner: $PROJECT_OWNER"
                            echo "VPC Name: $VPC_NAME"
                            echo "DNS Policy Name: $DNS_POLICY_NAME"
                            echo "DNS Policy Enabled: $DNS_POLICY_ENABLED"
                            echo "DNS Policy Logging Enabled: $DNS_POLICY_LOGGING_ENABLED"
                            echo "Status: $STATUS_MESSAGE"
                            echo $BLANK_LINE;
                        else
                            echo "\"$PROJECT_ID\", \"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$VPC_NAME\", \"$DNS_POLICY_NAME\", \"$DNS_POLICY_ENABLED\", \"$DNS_POLICY_LOGGING_ENABLED\", \"$STATUS_MESSAGE\""
                        fi
                    fi
                done
            else
                DNS_POLICY_NAME="No DNS Policy"
                DNS_POLICY_ENABLED="false"
                DNS_POLICY_LOGGING_ENABLED="Not applicable"
                STATUS_MESSAGE="Not applicable"

                if [[ $DEBUG == "True" ]]; then
                    echo "DEBUG: VPC Name: $VPC_NAME"
                fi

                # Print the results for VPC with no DNS policy
                if [[ $CSV != "True" ]]; then
                    echo "Project Name: $PROJECT_NAME"
                    echo "Project Application: $PROJECT_APPLICATION"
                    echo "Project Owner: $PROJECT_OWNER"
                    echo "VPC Name: $VPC_NAME"
                    echo "DNS Policy Name: $DNS_POLICY_NAME"
                    echo "DNS Policy Enabled: $DNS_POLICY_ENABLED"
                    echo "DNS Policy Logging Enabled: $DNS_POLICY_LOGGING_ENABLED"
                    echo "Status: $STATUS_MESSAGE"
                    echo $BLANK_LINE;
                else
                    echo "\"$PROJECT_NAME\", \"$PROJECT_OWNER\", \"$PROJECT_APPLICATION\", \"$VPC_NAME\", \"$DNS_POLICY_NAME\", \"$DNS_POLICY_ENABLED\", \"$DNS_POLICY_LOGGING_ENABLED\", \"$STATUS_MESSAGE\""
                fi
            fi
        done
    else
        if [[ $CSV != "True" ]]; then
            echo "No VPCs found for project $PROJECT_ID"
            echo $BLANK_LINE;
        fi
    fi
    sleep $SLEEP_SECONDS;
done


