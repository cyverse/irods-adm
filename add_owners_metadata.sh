#!/bin/bash

# This script:
# 1. Finds the latest report in the data/ directory
# 2. Extracts owner information from the JSON file
# 3. Queries LDAP to get full names for each owner
# 4. Adds AVUs to iRODS for all top-level directories in /iplant/home/shared/

# Set script to exit on any error
set -e

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATA_DIR="${SCRIPT_DIR}/data"

# LDAP configuration
LDAP_SERVER="ldap://ldap.iplantcollaborative.org"
LDAP_BASE="dc=iplantcollaborative,dc=org"

# Check for required commands
for cmd in jq ldapsearch ils imeta; do
    if ! command -v $cmd &>/dev/null; then
        echo "Error: Required command '$cmd' not found."
        exit 1
    fi
done

export IRODS_ENVIRONMENT_FILE
if [[ -z "$IRODS_ENVIRONMENT_FILE" ]]; then
    IRODS_ENVIRONMENT_FILE="$HOME/.irods/irods_environment.json"
fi

# Check for iRODS environment
if [[ ! -f "$IRODS_ENVIRONMENT_FILE" ]]; then
    echo "Error: iRODS environment file not found. Please configure iRODS first."
    exit 1
fi

# Test iRODS connection
if ! ils &>/dev/null; then
    echo "Error: Cannot connect to iRODS. Please check your configuration."
    exit 1
fi

# Function to find the latest report file
find_latest_report() {
    # shellcheck disable=SC2012
    ls -t "${DATA_DIR}"/report_*.json 2>/dev/null | head -n 1
}

# Function to get user's full name from LDAP
get_ldap_fullname() {
    local username="$1"

    # Query LDAP for the user's common name (cn)
    local fullname=""

    # Attempt LDAP query
    fullname=$(ldapsearch -x -H "$LDAP_SERVER" -b "$LDAP_BASE" "(uid=$username)" cn 2>/dev/null | grep "^cn:" | head -n 1 | sed 's/^cn: //')

    # If fullname is empty, use username as fallback
    if [ -z "$fullname" ]; then
        echo "Warning: No LDAP record found for $username, using username as fallback" >&2
        echo "$username"
    else
        echo "$fullname"
    fi
}

# Function to add AVU to iRODS collection if it doesn't exist
add_avu_if_not_exists() {
    local collection="$1"
    local attr="$2"
    local value="$3"
    local unit="$4"

    # Check if AVU with the same attribute and value exists
    if imeta ls -C "$collection" "$attr" | grep -q "value: $value"; then
        echo "AVU already exists for $collection: $attr $value $unit"
    else
        echo "Adding AVU to $collection: $attr $value $unit"
        imeta add -C "$collection" "$attr" "$value" "$unit"
    fi
}

# Main execution
echo "Starting iRODS project owner metadata update - $(date)"

# Find the latest report
latest_report=$(find_latest_report)

if [ -z "$latest_report" ]; then
    echo "Error: No report files found in ${DATA_DIR}"
    exit 1
fi

echo "Using latest report: $latest_report"

# Process each project in the report
jq -c '.[]' "$latest_report" | while read -r project_json; do
    # Extract project name
    project=$(echo "$project_json" | jq -r '.Project')

    # Extract owners string and check if it's null
    owners_string=$(echo "$project_json" | jq -r '.Owner')

    if [ "$owners_string" = "null" ] || [ -z "$owners_string" ]; then
        echo "No owners found for project: $project"
        continue
    fi

    echo "Processing project: $project"

    # iRODS collection path
    collection="/iplant/home/shared/$project"

    # Check if collection exists
    if ! ils "$collection" &>/dev/null; then
        echo "Warning: Collection $collection does not exist in iRODS. Skipping."
        continue
    fi

    # Split the owners string by semicolon
    echo "$owners_string" | tr ';' '\n' | while read -r username; do
        # Remove any leading/trailing whitespace
        username=$(echo "$username" | xargs)

        if [ -z "$username" ]; then
            continue
        fi

        echo "  Processing owner: $username"

        # Get full name from LDAP
        fullname=$(get_ldap_fullname "$username")

        echo "    Full name: $fullname"

        # Add AVU to collection
        #add_avu_if_not_exists "$collection" "ipc::project-owner" "$username" "$fullname"
    done
done

echo "Completed iRODS project owner metadata update - $(date)"