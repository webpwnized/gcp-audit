#!/bin/bash

source common-constants.inc
source functions.inc
source ./standard-menu.inc

function csv_escape() {
    local raw="$1"
    printf '"%s"' "${raw//\"/\"\"}"
}

function output_header() {
    if [[ $CSV == "True" ]]; then
        echo "\"Project ID\",\"Project Name\",\"Application\",\"Owner\",\"Rule Name\",\"Direction\",\"Protocols\",\"Ports\",\"Source Ranges\",\"Destination Ranges\",\"Logging Enabled\",\"Disabled\",\"Has Violation\",\"Violation\""
    fi
}

function emit_csv() {
    local violation="$1"
    local has_violation="True"

    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
        "$(csv_escape "${PROJECT_ID:-}")" \
        "$(csv_escape "${PROJECT_NAME:-}")" \
        "$(csv_escape "${PROJECT_APPLICATION:-}")" \
        "$(csv_escape "${PROJECT_OWNER:-}")" \
        "$(csv_escape "${NAME:-}")" \
        "$(csv_escape "${DIRECTION:-}")" \
        "$(csv_escape "${PROTOCOL:-}")" \
        "$(csv_escape "${PORTS:-}")" \
        "$(csv_escape "${SOURCE_RANGES:-}")" \
        "$(csv_escape "${DEST_RANGES:-}")" \
        "$(csv_escape "${LOG_CONFIG:-}")" \
        "$(csv_escape "${DISABLED:-}")" \
        "$(csv_escape "$has_violation")" \
        "$(csv_escape "$violation")"
}

function is_non_rfc1918() {
    local cidr="$1"
    [[ "$cidr" =~ ^10\. ]] && return 1
    [[ "$cidr" =~ ^192\.168\. ]] && return 1
    [[ "$cidr" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && return 1
    return 0
}

if [[ -z "$PROJECT_ID" ]]; then
    PROJECTS=$(gcloud projects list --format="json")
else
    PROJECTS=$(gcloud projects list --format="json" --filter="name:$PROJECT_ID")
fi

if [[ $PROJECTS != "[]" ]]; then
    output_header

    echo "$PROJECTS" | jq -rc '.[]' | while IFS='' read -r PROJECT; do
        PROJECT_ID=$(echo "$PROJECT" | jq -r '.projectId')
        set_project "$PROJECT_ID"

        if ! api_enabled compute.googleapis.com; then
            [[ $CSV != "True" ]] && echo "Compute Engine API is not enabled on Project $PROJECT_ID"
            continue
        fi

        RESULTS=$(gcloud compute firewall-rules list --quiet --format="json" 2>/dev/null || echo "[]")

        if [[ $RESULTS != "[]" ]]; then
            get_project_details "$PROJECT_ID"

            echo "$RESULTS" | jq -rc '.[]' | while IFS='' read -r FIREWALL_RULE; do
                NAME=$(echo "$FIREWALL_RULE" | jq -rc '.name // empty')
                ALLOWED_PROTOCOLS=$(echo "$FIREWALL_RULE" | jq -rc '.allowed // empty')
                DENIED_PROTOCOLS=$(echo "$FIREWALL_RULE" | jq -rc '.denied // empty')
                DIRECTION=$(echo "$FIREWALL_RULE" | jq -rc '.direction // empty')
                LOG_CONFIG=$(echo "$FIREWALL_RULE" | jq -rc '.logConfig.enable // empty')
                SOURCE_RANGES=$(echo "$FIREWALL_RULE" | jq -rc '.sourceRanges // "null"')
                DEST_RANGES=$(echo "$FIREWALL_RULE" | jq -rc '.destinationRanges // "null"')
                DISABLED=$(echo "$FIREWALL_RULE" | jq -rc '.disabled // empty')

                HAS_INTERNET_SOURCE=""
                NON_RFC1918_SOURCES=()

                if [[ "$SOURCE_RANGES" != "null" ]]; then
                    echo "$SOURCE_RANGES" | jq -r '.[]' | while read -r src; do
                        if [[ "$src" == "0.0.0.0/0" ]]; then
                            HAS_INTERNET_SOURCE="True"
                        fi
                        if is_non_rfc1918 "$src"; then
                            NON_RFC1918_SOURCES+=("$src")
                        fi
                    done
                fi

                VIOLATIONS=()
                [[ "$LOG_CONFIG" == "false" ]] && VIOLATIONS+=("Firewall logging is not enabled")

                if [[ "$DIRECTION" == "INGRESS" ]]; then
                    [[ "$NAME" == "default-allow-icmp" ]] && VIOLATIONS+=("Default ICMP rule implemented")
                    [[ "$NAME" == "default-allow-ssh" ]] && VIOLATIONS+=("Default SSH rule implemented")
                    [[ "$NAME" == "default-allow-rdp" ]] && VIOLATIONS+=("Default RDP rule implemented")
                    [[ "$NAME" == "default-allow-internal" ]] && VIOLATIONS+=("Default Internal rule implemented")

                    [[ "$DEST_RANGES" == "null" ]] && VIOLATIONS+=("Ingress rule lacks destination or target")
                    [[ "$ALLOWED_PROTOCOLS" != "" && "$HAS_INTERNET_SOURCE" == "True" ]] && VIOLATIONS+=("Allows access from entire Internet")

                    if [[ "$ALLOWED_PROTOCOLS" != "" ]]; then
                        echo "$ALLOWED_PROTOCOLS" | jq -rc '.[]?' | while IFS='' read -r ALLOWED_PROTOCOL; do
                            PROTOCOL=$(echo "$ALLOWED_PROTOCOL" | jq -rc '.IPProtocol // "unknown"')
                            PORTS=$(echo "$ALLOWED_PROTOCOL" | jq -rc '.ports // empty')
                            PORT_LIST=()
                            [[ "$PORTS" != "" ]] && PORT_LIST=($(echo "$PORTS" | jq -r '.[]'))

                            for port in "${PORT_LIST[@]}"; do
								case "$port" in
									1-65535) VIOLATIONS+=("Allows all ports for protocol $PROTOCOL") ;;
									21)      VIOLATIONS+=("Rule includes port 21/FTP") ;;
									22)      [[ "$HAS_INTERNET_SOURCE" == "True" && "${#NON_RFC1918_SOURCES[@]}" -gt 0 ]] && VIOLATIONS+=("Port 22/SSH from non-RFC1918 source") ;;
									23)      VIOLATIONS+=("Rule includes port 23/Telnet") ;;
									25)      VIOLATIONS+=("Rule includes port 25/SMTP") ;;
									80)      VIOLATIONS+=("Rule includes port 80/HTTP") ;;
									110)     VIOLATIONS+=("Rule includes port 110/POP3") ;;
									143)     VIOLATIONS+=("Rule includes port 143/IMAP") ;;
									443)     VIOLATIONS+=("Rule includes port 443/HTTPS") ;;
									3389)    [[ "$HAS_INTERNET_SOURCE" == "True" && "${#NON_RFC1918_SOURCES[@]}" -gt 0 ]] && VIOLATIONS+=("Port 3389/RDP from non-RFC1918 source") ;;
									1433)    VIOLATIONS+=("Rule includes port 1433/SQL Server") ;;
									3306)    VIOLATIONS+=("Rule includes port 3306/MySQL") ;;
									1521)    VIOLATIONS+=("Rule includes port 1521/Oracle") ;;
									5432)    VIOLATIONS+=("Rule includes port 5432/PostgreSQL") ;;
								esac
							done

                            if [[ $CSV == "True" ]]; then
                                for v in "${VIOLATIONS[@]}"; do
                                    emit_csv "$v"
                                done
                            else
                                echo "Project Name: $PROJECT_NAME"
                                echo "Project Application: $PROJECT_APPLICATION"
                                echo "Project Owner: $PROJECT_OWNER"
                                echo "Name: $NAME ($DIRECTION)"
                                echo "Allowed: $ALLOWED_PROTOCOLS"
                                echo "Denied: $DENIED_PROTOCOLS"
                                echo "Source Ranges: $SOURCE_RANGES"
                                echo "Destination Ranges: $DEST_RANGES"
                                echo "Logging: $LOG_CONFIG"
                                echo "Disabled: $DISABLED"
                                for v in "${VIOLATIONS[@]}"; do echo "VIOLATION: $v"; done
                                echo
                            fi
                        done
                    fi
                fi
            done
        else
            [[ $CSV != "True" ]] && echo "No firewall rules found for $PROJECT_ID" && echo
        fi
        sleep "${SLEEP_SECONDS:-2}"
    done
else
    [[ $CSV != "True" ]] && echo "No projects found" && echo
fi
