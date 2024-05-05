#!/bin/bash

source common-constants.inc;
source functions.inc;

# Print output for each load balancer and its backend service
function printOutput() {

    if [[ $CSV != "True" ]]; then
        echo "Project Name: $PROJECT_NAME";
        echo "Project Application: $PROJECT_APPLICATION";
        echo "Project Owner: $PROJECT_OWNER";
        echo "Load Balancer Name: $LOAD_BALANCER_NAME";
        echo "Backend Service Name: $BACKEND_SERVICE_NAME";
        echo "Logging Status: $IS_LOGGING_ENABLED";
        echo "Logging Status Message: $IS_LOGGING_ENABLED_MESSAGE";
        echo $BLANK_LINE;
    else 
        echo "\"$PROJECT_NAME\", \"$PROJECT_APPLICATION\", \"$PROJECT_OWNER\", \"$LOAD_BALANCER_NAME\", \"$BACKEND_SERVICE_NAME\", \"$IS_LOGGING_ENABLED\", \"$IS_LOGGING_ENABLED_MESSAGE\"";
    fi;
};


describe_tcp_proxies() {
  local PROXY_NAME=$1
  local REGION

  # Attempt to get as a global target TCP proxy
  PROXY_DETAILS=$(gcloud compute target-tcp-proxies describe $PROXY_NAME --global --format="json" 2>/dev/null)

  # If global target TCP proxy not found, try to get regional
  if [[ $? -ne 0 ]]; then
    # Get all regions
    REGIONS=$(gcloud compute regions list --format="value(name)")

    # Loop over regions to find target TCP proxy
    for REGION in $REGIONS; do
      PROXY_DETAILS=$(gcloud compute target-tcp-proxies describe $PROXY_NAME --region="$REGION" --format="json" 2>/dev/null)
      if [[ $? -eq 0 ]]; then
        echo $PROXY_DETAILS
        break
      fi
    done
  else
    echo $PROXY_DETAILS
  fi
};

# Function to describe target SSL proxies (SSL Proxy Load Balancers)
describe_ssl_proxies() {
  local PROXY_NAME=$1
  local REGION

  # Attempt to get as a global target SSL proxy
  PROXY_DETAILS=$(gcloud compute target-ssl-proxies describe $PROXY_NAME --global --format="json" 2>/dev/null)

  # If global target SSL proxy not found, try to get regional
  if [[ $? -ne 0 ]]; then
    # Get all regions
    REGIONS=$(gcloud compute regions list --format="value(name)")

    # Loop over regions to find target SSL proxy
    for REGION in $REGIONS; do
      PROXY_DETAILS=$(gcloud compute target-ssl-proxies describe $PROXY_NAME --region="$REGION" --format="json" 2>/dev/null)
      if [[ $? -eq 0 ]]; then
        echo $PROXY_DETAILS
        break
      fi
    done
  else
    echo $PROXY_DETAILS
  fi
};

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

# Print debug output
function printDebugOutput() {
    echo "Debug: Backend Service Details for $BACKEND_SERVICE_NAME"
    BACKEND_SERVICE_JSON=$(describe_backend_services $BACKEND_SERVICE_NAME)
    echo $BACKEND_SERVICE_JSON | jq
    echo "End of Backend Service Details for $BACKEND_SERVICE_NAME"
    echo $BLANK_LINE;
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
function processBackendServices() {
    local BACKEND_SERVICES="$1"

    declare -A PROCESSED_BACKEND_SERVICES

    # Check if backend services exist
    if [[ -z $BACKEND_SERVICES ]]; then
        BACKEND_SERVICE_NAME="This load balancer has no backends configured"
        IS_LOGGING_ENABLED="N/A"
        IS_LOGGING_ENABLED_MESSAGE="N/A"
        # Print output in CSV format if CSV output is enabled, else print regular output
        printOutput
    else
        for BACKEND_SERVICE_NAME in $BACKEND_SERVICES; do
            # Skip backend service if it was already processed
            if [[ ${PROCESSED_BACKEND_SERVICES[$BACKEND_SERVICE_NAME]} ]]; then
                continue
            fi
            PROCESSED_BACKEND_SERVICES[$BACKEND_SERVICE_NAME]=1
           
            # Get all backend services for the load balancer
            BACKEND_SERVICE_DETAILS=$(describe_backend_services $BACKEND_SERVICE_NAME)

            if [[ -z "$BACKEND_SERVICE_DETAILS" ]]; then
                echo "Could not fetch details for backend service: $BACKEND_SERVICE_NAME"
                continue
            fi;

            # Check if logging is enabled for the backend service
            IS_LOGGING_ENABLED=$(echo $BACKEND_SERVICE_DETAILS | jq -rc '.logConfig.enable // "false"')
            if [[ $IS_LOGGING_ENABLED == "true" ]]; then
                IS_LOGGING_ENABLED_MESSAGE="The Load Balancer has logging enabled"
            else
                IS_LOGGING_ENABLED_MESSAGE="VIOLATION: The Load Balancer does not have logging enabled"
            fi;

            # Print debug output if debugging is enabled
            if [[ $DEBUG == "True" ]]; then
                printDebugOutput
            fi;

            # Print output in CSV format if CSV output is enabled, else print regular output
            printOutput
        done
    fi;
}

# Function to print the separator
function printSeparator() {
    if [[ $CSV != "True" ]]; then
        echo "---------------------------------------------------------------------------------"
    fi
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

# Print CSV header if CSV output is enabled
if [[ $CSV == "True" ]]; then
echo "\"PROJECT_NAME\", \"PROJECT_APPLICATION\", \"PROJECT_OWNER\", \"LOAD_BALANCER_NAME\", \"BACKEND_SERVICE_NAME\", \"IS_LOGGING_ENABLED\", \"IS_LOGGING_ENABLED_MESSAGE\"";
fi

if [[ $PROJECTS != "[]" ]]; then
  # Iterate over each project
  for PROJECT_ID in $PROJECT_IDS; do
      set_project $PROJECT_ID

      # Check if Compute Engine API is enabled for the project
      if ! api_enabled compute.googleapis.com; then
          if [[ $CSV != "True" ]]; then
              echo "Compute Engine API is not enabled for Project $PROJECT_ID.";
          fi
          continue
      fi

      # Get project details
      get_project_details $PROJECT_ID

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

              printSeparator
              processBackendServices "$BACKEND_SERVICES"
          done
      fi;
      
      # Get list of TCP proxies (TCP Load Balancers) in the project
      TCP_PROXY_LIST=$(gcloud compute target-tcp-proxies list --format="json")

      # Check if any TCP load balancer is found in the project
      check_load_balancer_found "TCP" "$TCP_PROXY_LIST"

      # Iterate over each TCP load balancer in the list
      if [ $? -eq 0 ]; then
          echo "$TCP_PROXY_LIST" | jq -rc '.[]' | while IFS='' read LOAD_BALANCER; do
              LOAD_BALANCER_NAME=$(echo "$LOAD_BALANCER" | jq -rc '.name')

              # Get all backend services for the TCP load balancer
              BACKEND_SERVICES=$(describe_tcp_proxies "$LOAD_BALANCER_NAME" | jq -rc '.proxyHeader' | awk -F '/' '{print $NF}')

              printSeparator
              processBackendServices "$BACKEND_SERVICES"
        
          done
      fi;
      
      # Get list of SSL proxies (SSL Load Balancers) in the project
      SSL_PROXY_LIST=$(gcloud compute target-ssl-proxies list --format="json")

      # Check if any SSL load balancer is found in the project
      check_load_balancer_found "SSL" "$SSL_PROXY_LIST"

      # Iterate over each SSL load balancer in the list
      if [ $? -eq 0 ]; then
          echo "$SSL_PROXY_LIST" | jq -rc '.[]' | while IFS='' read LOAD_BALANCER; do
              LOAD_BALANCER_NAME=$(echo "$LOAD_BALANCER" | jq -rc '.name')

              # Get all backend services for the SSL load balancer
              BACKEND_SERVICES=$(describe_ssl_proxies "$LOAD_BALANCER_NAME" | jq -rc '.proxyHeader' | awk -F '/' '{print $NF}')

              printSeparator
              processBackendServices "$BACKEND_SERVICES"

          done
      fi;
      printSeparator;

      sleep $SLEEP_SECONDS;
  done;
else # if no projects
  if [[ $CSV != "True" ]]; then
    echo "No projects found"
    echo $BLANK_LINE;
  fi
fi
