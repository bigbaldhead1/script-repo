#!/usr/bin/env bash

# GitHub: https://github.com/slyfox1186/script-repo/blob/main/Bash/Misc/System/monitor.sh
# Script version: 1.5
# Last update: 05-28-24

## Important information
# Arguments take priority over hardcoded variables

# Define variables
monitor_dir="${PWD}"  # Default directory to monitor
include_access=false  # Flag to include access events
log_file=""           # Log file path

# Define colors
cyan='\033[36m'       # Cyan for access events
green='\033[32m'      # Green for create events
red='\033[31m'        # Red for delete events
yellow='\033[33m'     # Yellow for modify events
magenta='\033[35m'    # Magenta for move events
reset='\033[0m'       # Resets the color to none

# Function to display help
display_help() {
    echo -e "${yellow}Usage${magenta}:${reset} ${0} [options]"
    echo
    echo -e "${yellow}Options${magenta}:${reset}"
    echo "  -a, --access       Include \"access\" events"
    echo "  -d, --directory    Specify the directory to monitor"
    echo "  -l, --log          Specify the log file to write events"
    echo "  -h, --help         Display this help message"
    echo
    echo -e "${yellow}Examples${magenta}:${reset}"
    echo "./monitor.sh --help"
    echo "./monitor.sh --directory \"/path/to/folder\""
    echo "./monitor.sh -a -d \"/path/to/folder\""
    echo "./monitor.sh -l /path/to/logfile.log"
}

# Function to parse arguments
parse_arguments() {
    while [[ "${#}" -gt 0 ]]; do
        case "${1}" in
            -a|--access)
                include_access=true
                shift
                ;;
            -d|--directory)
                monitor_dir="${2}"
                shift 2
                ;;
            -h|--help)
                display_help
                exit 0
                ;;
            -l|--log)
                log_file="${2}"
                shift 2
                ;;
            *)
                echo "Unknown option: ${1}"
                display_help
                exit 1
                ;;
        esac
    done
}

# Function to check if inotifywait is installed
check_command() {
    if ! command -v inotifywait &>/dev/null; then
        echo -e "${red}[ERROR]${reset} The command inotifywait is not installed."
        echo -e "${green}[INFO]${reset} This is commonly installed by your package manager inside the package inotify-tools"
        exit 1
    fi
}

# Function to get the color for an event
get_color_for_event() {
    local event
    event="${1}"
    case "${event}" in
        *ACCESS*)
            echo "${cyan}"
            ;;
        *CREATE*)
            echo "${green}"
            ;;
        *DELETE*)
            echo "${red}"
            ;;
        *MODIFY*)
            echo "${yellow}"
            ;;
        *MOVE*)
            echo "${magenta}"
            ;;
        *)
            echo "${reset}"
            ;;
    esac
}

# Main function to monitor directory
monitor_directory() {
    local events
    events="create,delete,modify,move"
    if [[ "${include_access}" = true ]]; then
        events+=",access"
    fi

    if [[ ! -d "${monitor_dir}" ]]; then
        echo -e "${red}[ERROR]${reset} The directory to monitor does not exist."
        exit 1
    fi

    echo "Monitoring directory: ${monitor_dir}"
    inotifywait -mre "${events}" "${monitor_dir}" |
    while read -r event; do
        printf -v timestamp '%(%m-%d-%Y %I:%M:%S %p)T' -1
        color=$(get_color_for_event "${event}")
        event_log="[${timestamp}] ${event}"
        echo -e "${color}${event_log}${reset}"
        
        if [[ -n "${log_file}" ]]; then
            echo "${event_log}" >> "${log_file}"
        fi
    done
}

# Parse arguments
parse_arguments "${@}"

# Check if inotifywait is installed
check_command

# Monitor the directory
monitor_directory
