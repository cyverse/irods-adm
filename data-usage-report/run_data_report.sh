#!/usr/bin/env bash

# run_data_report.sh
# Simple wrapper script to run the data access report generator (main.py)
# Can be used with cron to pipe output to mail
#
# © 2025, The Arizona Board of Regents on behalf of The University of Arizona.
# For license information, see https://cyverse.org/license.

set -o errexit -o nounset -o pipefail

readonly EXEC_NAME="$(basename "$0")"
readonly VERSION="1.0"
readonly DEFAULT_RESOURCES="demoResc iplant"
readonly SCRIPT_DIR="$(dirname "$(realpath "$0")")"
readonly LOG_DIR="$SCRIPT_DIR/logs"

# Database connection info
PG_HOST=""
PG_PORT=""
PG_USER=""

# Other settings
RESOURCES=""
GENERATE_HTML="false"
DEBUG="false"
FORCE_REFRESH="false"
MAX_REPORT_AGE=5
IRODS_UPLOAD_LOCATION="/iplant/home/shared/CyVerse_DSStats/data-products/project-data-usage"

show_help() {
    cat <<EOF

$EXEC_NAME version $VERSION

Usage:
 $EXEC_NAME -h|--help
 $EXEC_NAME -v|--version
 $EXEC_NAME [-d|--debug] [-f|--force-refresh] [--html] [-m|--max-age DAYS]
    [-H|--dbms-host DBMS-HOST] [-P|--dbms-port DBMS-PORT] [-U|--db-user DB-USER]
    [-r|--resources RESOURCES] [--irods-location IRODS-PATH]

A wrapper script for the data access report generator (main.py).
Output is suitable for emailing and is designed to be used with cron.

Example cron usage:
    0 2 * * 1 /path/to/$EXEC_NAME -r "demoResc iplant" --html | mail -s "Data Access Report" admin@example.com

Options:
 -H, --dbms-host DBMS-HOST    The domain name or IP address of the server hosting
                              the PostgreSQL DBMS containing the ICAT DB
 -P, --dbms-port DBMS-PORT    The TCP port the DBMS listens on
 -U, --db-user DB-USER        The account used to authorize the connection to the
                              ICAT database
 -r, --resources RESOURCES    Space-separated list of resources to analyze (in quotes)
                              Default: "$DEFAULT_RESOURCES"
 -m, --max-age DAYS           Maximum age of previous reports to reuse (in days)
                              Default: $MAX_REPORT_AGE
 --irods-location IRODS-PATH  iRODS path where to upload HTML reports
                              Default: $IRODS_UPLOAD_LOCATION
 --html                       Generate HTML report in addition to plain text
 -f, --force-refresh          Force regeneration of the report
 -d, --debug                  Display debug messages
 -h, --help                   Show help and exit
 -v, --version                Show version and exit

Environment Variables:
 PGHOST  Provides the default value for the DBMS host
 PGPORT  Provides the default value for the TCP port the DBMS listens on
 PGUSER  Provides the default value for the account used to authorize the connection

© 2025, The Arizona Board of Regents on behalf of The University of Arizona.
For license information, see https://cyverse.org/license.
EOF
}

# Process command line arguments
process_args() {
    local opts
    if ! opts=$(getopt \
        --name "$EXEC_NAME" \
        --options dhH:P:U:r:m:fv \
        --longoptions debug,help,version,dbms-host:,dbms-port:,db-user:,resources:,html,force-refresh,max-age:,irods-location: \
        -- "$@"); then
        show_help >&2
        exit 1
    fi

    eval set -- "$opts"

    while true; do
        case "$1" in
            -H|--dbms-host)
                PG_HOST="$2"
                shift 2
                ;;
            -P|--dbms-port)
                PG_PORT="$2"
                shift 2
                ;;
            -U|--db-user)
                PG_USER="$2"
                shift 2
                ;;
            -r|--resources)
                RESOURCES="$2"
                shift 2
                ;;
            -m|--max-age)
                MAX_REPORT_AGE="$2"
                shift 2
                ;;
            --irods-location)
                IRODS_UPLOAD_LOCATION="$2"
                shift 2
                ;;
            --html)
                GENERATE_HTML="true"
                shift
                ;;
            -f|--force-refresh)
                FORCE_REFRESH="true"
                shift
                ;;
            -d|--debug)
                DEBUG="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$VERSION"
                exit 0
                ;;
            --)
                shift
                break
                ;;
        esac
    done

    # Set defaults if not provided
    RESOURCES="${RESOURCES:-$DEFAULT_RESOURCES}"
    
    # Export PostgreSQL environment variables for Python script
    if [[ -n "$PG_HOST" ]]; then
        export PGHOST="$PG_HOST"
    fi
    if [[ -n "$PG_PORT" ]]; then
        export PGPORT="$PG_PORT"
    fi
    if [[ -n "$PG_USER" ]]; then
        export PGUSER="$PG_USER"
    fi
}

# Check for existing instance of script
check_existing_instance() {
    local pid
    for pid in $(pgrep --full "$EXEC_NAME"); do
        if (( pid != $$ && pid != PPID )); then
            echo "$EXEC_NAME already running with PID $pid" >&2
            exit 1
        fi
    done
}

# Setup logging if debug mode is enabled
setup_logging() {
    if [[ "$DEBUG" == "true" ]]; then
        # Create log directory if it doesn't exist
        if [[ ! -d "$LOG_DIR" ]]; then
            mkdir -p "$LOG_DIR"
        fi
        
        # Log file with date in name
        LOG_FILE="$LOG_DIR/data_report_$(date '+%Y%m%d').log"
        
        # Log to file in debug mode
        exec 2> >(tee -a "$LOG_FILE")
        echo "[DEBUG] Logging to $LOG_FILE" >&2
    fi
}

# Main function
main() {
    process_args "$@"
    check_existing_instance
    setup_logging
    
    # activate myenv if it's present, else build one using requirements.txt
    if [[ -d "$SCRIPT_DIR/myenv" ]]; then
        echo "[INFO] Activating existing myenv virtual environment" >&2
        source "$SCRIPT_DIR/myenv/bin/activate"
    else
        echo "[INFO] myenv not found. Creating new virtual environment from requirements.txt" >&2
        python3 -m venv "$SCRIPT_DIR/myenv"
        source "$SCRIPT_DIR/myenv/bin/activate"
        pip install -r "$SCRIPT_DIR/requirements.txt" > /dev/null
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed to install requirements. Please check requirements.txt." >&2
            exit 1
        fi
        echo "[INFO] Virtual environment created and requirements installed." >&2
    fi    

    # if data/, logs/, and reports/ directories are not present, create them
    for dir in data logs reports; do
        if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
            mkdir -p "$SCRIPT_DIR/$dir"
            echo "[INFO] Created $dir directory." >&2
        fi
    done

    # Build command
    local cmd="python3 $SCRIPT_DIR/main.py"
    
    # Add arguments
    if [[ -n "$PG_HOST" ]]; then
        cmd="$cmd -H $PG_HOST"
    fi
    if [[ -n "$PG_PORT" ]]; then
        cmd="$cmd -P $PG_PORT"
    fi
    if [[ -n "$PG_USER" ]]; then
        cmd="$cmd -U $PG_USER"
    fi
    if [[ "$GENERATE_HTML" == "true" ]]; then
        cmd="$cmd --html"
    fi
    if [[ "$FORCE_REFRESH" == "true" ]]; then
        cmd="$cmd --force-refresh"
    fi
    if [[ -n "$MAX_REPORT_AGE" ]]; then
        cmd="$cmd --max-report-age $MAX_REPORT_AGE"
    fi
    if [[ -n "$IRODS_UPLOAD_LOCATION" ]]; then
        cmd="$cmd --irods-upload-location $IRODS_UPLOAD_LOCATION"
    fi
    if [[ "$DEBUG" == "true" ]]; then
        cmd="$cmd --debug"
    fi
    
    # Add resources last
    cmd="$cmd $RESOURCES"
    
    # Log the command if in debug mode
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] Running command: $cmd" >&2
    fi
    
    # Execute the Python script
    # Let output go to stdout for piping to mail, errors to stderr
    eval "$cmd"
}

# Run main with all arguments
main "$@"