#!/bin/bash

readonly BLANK_LINE=""
readonly SLEEP_SECONDS=1

# Get the script name without the "./" prefix
SCRIPT_NAME=$(basename "$0")

# Construct the error log file name with the script name and current date/time
readonly ERROR_LOG_FILE="errors-${SCRIPT_NAME%.*}-$(date +"%Y-%m-%d-%H-%M-%S").log"