#!/bin/bash
#
# Script Name: [SCRIPT_NAME]
# Description: [BRIEF_DESCRIPTION]
# Author: [AUTHOR]
# Date: [DATE]
# Version: 1.0
#
# Usage: ./script_name.sh [arguments]
# Example: ./script_name.sh arg1 arg2
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Default values
DEFAULT_VALUE="default"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Functions
usage() {
    echo "Usage: $SCRIPT_NAME [OPTIONS] ARGUMENTS"
    echo
    echo "Description of what this script does."
    echo
    echo "OPTIONS:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --verbose       Enable verbose output"
    echo "  -d, --dry-run       Show what would be done without executing"
    echo
    echo "ARGUMENTS:"
    echo "  arg1                Description of first argument"
    echo "  arg2                Description of second argument (optional)"
    echo
    echo "EXAMPLES:"
    echo "  $SCRIPT_NAME example_arg1"
    echo "  $SCRIPT_NAME example_arg1 example_arg2"
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Cleanup function
cleanup() {
    log_debug "Cleaning up..."
    # Add cleanup operations here
}

# Set up cleanup trap
trap cleanup EXIT

# Parse command line arguments
VERBOSE=false
DRY_RUN=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -*|--*)
            log_error "Unknown option $1"
            usage
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

# Validate arguments
if [[ $# -lt 1 ]]; then
    log_error "Missing required arguments"
    usage
fi

ARG1="$1"
ARG2="${2:-$DEFAULT_VALUE}"

# Main script logic
main() {
    log_info "Starting $SCRIPT_NAME"
    log_debug "Script directory: $SCRIPT_DIR"
    log_debug "Argument 1: $ARG1"
    log_debug "Argument 2: $ARG2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    # Add your main logic here
    log_info "Processing $ARG1..."
    
    # Example of conditional execution for dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would execute: some_command $ARG1"
    else
        # some_command "$ARG1"
        log_info "Executed successfully"
    fi
    
    log_info "$SCRIPT_NAME completed successfully"
}

# Run main function
main "$@"