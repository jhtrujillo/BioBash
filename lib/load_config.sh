#!/bin/bash
# -----------------------------------------------------------------------------
# Configuration Loader for bahs-suit
# -----------------------------------------------------------------------------

# Get the directory where this script is located
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$LIB_DIR")"
CONF_FILE="$BASE_DIR/conf/biobash.conf"

if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    echo "ERROR: Configuration file not found at $CONF_FILE"
    exit 1
fi

# Export variables to make them available to sub-scripts
export BIODATA_WGS CONSECUTIVOS_FILE NGSEP_JAR JAVA_BIN JVM_MAX_HEAP JVM_STACK_SIZE
export DEFAULT_I DEFAULT_X DEFAULT_PROC LOG_DIR
