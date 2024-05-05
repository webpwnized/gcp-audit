#!/bin/bash

source functions.inc

# Function to describe backend services
describe_backend_services() {
  local BACKEND_SERVICE_NAME=$1
  local REGION

  # Attempt to get as a global backend service
  BACKEND_SERVICE=$(gcloud compute backend-services describe $BACKEND_SERVICE_NAME --global --format="json" 2>/dev/null)

  # If global backend service not found, try to get regional
  if [[ $? -ne 0 ]]; then
    # Get all regions
    REGIONS=$(gcloud compute regions list --format="value(name)")

    # Loop over regions to find backend service
    for REGION in $REGIONS; do
      BACKEND_SERVICE=$(gcloud compute backend-services describe $BACKEND_SERVICE_NAME --region="$REGION" --format="json" 2>/dev/null)
      if [[ $? -eq 0 ]]; then
        echo $BACKEND_SERVICE
        break
      fi
    done
  else
    echo $BACKEND_SERVICE
  fi
};



# Function to describe url maps (load balancers)
describe_url_maps() {
  local LOAD_BALANCER_NAME=$1
  local REGION

  # Attempt to get as a global url map
  URL_MAP_DETAILS=$(gcloud compute url-maps describe $LOAD_BALANCER_NAME --global --format="json" 2>/dev/null)

  # If global url map not found, try to get regional
  if [[ $? -ne 0 ]]; then
    # Get all regions
    REGIONS=$(gcloud compute regions list --format="value(name)")

    # Loop over regions to find url map
    for REGION in $REGIONS; do
      URL_MAP_DETAILS=$(gcloud compute url-maps describe $LOAD_BALANCER_NAME --region="$REGION" --format="json" 2>/dev/null)
      if [[ $? -eq 0 ]]; then
        echo $URL_MAP_DETAILS
        break
      fi
    done
  else
    echo $URL_MAP_DETAILS
  fi
};


# Function to process backend services for a load balancer
processBackendServices() {
    local BACKEND_SERVICES="$1"
    declare -A PROCESSED_BACKEND_SERVICES

    # Get all regions
    REGIONS=$(gcloud compute regions list --format="value(name)")

    echo "Load Balancer Name: $LOAD_BALANCER_NAME"

    # Get Frontend Hosts for HTTP and HTTPS
    FRONTEND_HOSTS=$(echo $URL_MAP_DETAILS | jq -r '.hostRules[].hosts[]')

    # Print Frontend URLs
    for HOST in $FRONTEND_HOSTS; do
        echo "Frontend Load Balancer URL: $HOST"
    done
    echo $BLANK_LINE;


    # Check if backend services exist
    if [[ -z $BACKEND_SERVICES ]]; then
        echo "This load balancer has no backends configured"
    else
        for BACKEND_SERVICE_NAME in $BACKEND_SERVICES; do
            # Skip backend service if it was already processed
            if [[ ${PROCESSED_BACKEND_SERVICES[$BACKEND_SERVICE_NAME]} ]]; then
                continue
            fi
            PROCESSED_BACKEND_SERVICES[$BACKEND_SERVICE_NAME]=1

            echo "Backend Service Name: $BACKEND_SERVICE_NAME"
            
            
            # List Network Endpoint Groups here
            BACKEND_SERVICE_DETAILS=$(describe_backend_services "$BACKEND_SERVICE_NAME")

            NETWORK_ENDPOINT_GROUPS=$(echo $BACKEND_SERVICE_DETAILS | jq -r '.backends[].group' | awk -F '/' '{print $NF}')

            for NETWORK_ENDPOINT_GROUP in $NETWORK_ENDPOINT_GROUPS; do
                echo "Network Endpoint Name: $NETWORK_ENDPOINT_GROUP"

                for REGION in $REGIONS; do
                    # Describe the NEG, checking each region
                    NEG_DETAILS=$(gcloud compute network-endpoint-groups describe $NETWORK_ENDPOINT_GROUP --region=$REGION --format=json 2>/dev/null)
                    if [[ $? -eq 0 ]]; then

                        # Here, check if it's a Cloud Run service, print the service name.
                        IS_CLOUD_RUN=$(echo $NEG_DETAILS | jq -r '.cloudRun')

                        if [[ $IS_CLOUD_RUN != "null" ]]; then
                            SERVICE_NAME=$(echo $NEG_DETAILS | jq -r '.cloudRun.service')
                            echo "Endpoint Type: Cloud Run"
                            echo "   Service Name: $SERVICE_NAME"
                            echo " "
                        else
                            echo "Not Associated with Cloud Run Service"
                            echo " "
                        fi
                        break
                    fi       
                done 
            done
        done
    fi
}


# Function to check if any load balancer is found in the project for the given load balancer type
check_load_balancer_found() {
  local load_balancer_type=$1
  local lb_list_var=$2

  if [ "$(echo "$lb_list_var" | jq -rc 'length')" -eq "0" ]; then
    if [[ $CSV != "True" ]]; then
      echo "No $load_balancer_type load balancer found for Project $PROJECT_ID";
      echo $BLANK_LINE;
    fi
    return 1
  fi

  return 0
}

declare PROJECT_IDS="";
declare DEBUG="False";
declare CSV="False";
declare HELP=$(cat << EOL
    $0 [-p, --project PROJECT] [-c, --csv] [-d, --debug] [-h, --help]    
EOL
);

# Parse the script arguments
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--debug") set -- "$@" "-d" ;;
    "--csv") set -- "$@" "-c" ;;
    "--project") set -- "$@" "-p" ;;
    *) set -- "$@" "$arg"
  esac
done

# Process the parsed arguments
while getopts "hdcp:" option
do 
    case "${option}"
        in
        p) PROJECT_IDS=${OPTARG};;
        d) DEBUG="True";;
        c) CSV="True";;
        h) echo "$HELP"; 
           exit 0;;
    esac;
done

# If no projects are specified, get all projects
if [[ $PROJECT_IDS == "" ]]; then
    declare PROJECT_IDS=$(get_projects);
fi

# ...

if [[ $PROJECTS != "[]" ]]; then
  # Iterate over each project
  for PROJECT_ID in $PROJECT_IDS; do
        set_project $PROJECT_ID

        if ! api_enabled run.googleapis.com; then
            if [[ $CSV != "True" ]]; then
                echo "Cloud Run API is not enabled for Project $PROJECT_ID.";
                echo ""
            fi
            continue
        fi

        # Check if Compute Engine API is enabled for the project
        if ! api_enabled compute.googleapis.com; then
            if [[ $CSV != "True" ]]; then
                echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
                echo ""
            fi
            continue
        fi


        # Get project details
        get_project_details $PROJECT_ID

        declare RUN_SERVICES=$(gcloud run services list --format="json");
            if [[ $RUN_SERVICES != "[]" ]]; then
                echo "Cloud Run Services for Project $PROJECT_ID";


                # Print project information once per project
                echo "Project Name: $PROJECT_NAME"
                echo "Project Application: $PROJECT_APPLICATION"
                echo "Project Owner: $PROJECT_OWNER"
                echo ""

                # Get list of HTTP and HTTPS load balancers for the project
                HTTP_LOAD_BALANCER_LIST=$(gcloud compute url-maps list --format=json)

                # Check if any HTTP(S) load balancer is found in the project
                check_load_balancer_found "HTTP(S)" "$HTTP_LOAD_BALANCER_LIST"

                # Iterate over each HTTP(S) load balancer in the list
                if [ $? -eq 0 ]; then
                    echo "$HTTP_LOAD_BALANCER_LIST" | jq -rc '.[]' | while IFS='' read LOAD_BALANCER; do
                        LOAD_BALANCER_NAME=$(echo "$LOAD_BALANCER" | jq -rc '.name')
                        URL_MAP_DETAILS=$(describe_url_maps "$LOAD_BALANCER_NAME")
                        
                        # Get all backend services for the load balancer
                        BACKEND_SERVICES=$(echo $URL_MAP_DETAILS | jq -rc '[.defaultService, .pathMatchers[]?.defaultService?, .pathMatchers[]?.pathRules[]?.service?] | map(select(.!=null))[]' | awk -F '/' '{print $NF}')

                        processBackendServices "$BACKEND_SERVICES"
                    done
                fi;

            # Loop over the Cloud Run services and print their names
            echo "Cloud Run Service Names:"
            echo "$RUN_SERVICES" | jq -rc '.[].metadata.name'

            else
                echo "NO Cloud Run Services found for Project $PROJECT_ID"
                echo ""
            fi;
        sleep $SLEEP_SECONDS;
    done 
else # if no projects
  if [[ $CSV != "True" ]]; then
    echo "No projects found"
    echo $BLANK_LINE;
  fi
fi

