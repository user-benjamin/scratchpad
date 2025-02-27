#!/bin/bash

# docker_cleanup.sh - A script to identify and clean up unused Docker containers
# 
# This script provides various options to identify and remove Docker containers
# that are considered "unused" based on different criteria.

set -e

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "A script to identify and clean up unused Docker containers."
    echo
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -l, --list                 List all unused containers without removing them"
    echo "  -a, --all                  Remove all stopped containers"
    echo "  -d, --days DAYS            Remove containers stopped for more than DAYS days"
    echo "  -n, --name PATTERN         Remove containers with names matching PATTERN"
    echo "  -e, --exited-code CODE     Remove containers with specific exit code"
    echo "  -f, --force                Force removal of containers (even if running)"
    echo "  -y, --yes                  Don't ask for confirmation before removing"
    echo "  -p, --prune                Run docker system prune (removes containers, networks, images)"
    echo "  -v, --verbose              Enable verbose output"
    echo
    echo "Examples:"
    echo "  $0 --list                  # List all unused containers"
    echo "  $0 --all                   # Remove all stopped containers"
    echo "  $0 --days 7                # Remove containers stopped for more than 7 days"
    echo "  $0 --name 'test-*'         # Remove containers with names starting with 'test-'"
    echo "  $0 --exited-code 1         # Remove containers that exited with code 1"
    echo "  $0 --all --force --yes     # Remove all stopped containers without confirmation"
    exit 1
}

# Initialize variables
LIST_ONLY=false
REMOVE_ALL=false
DAYS=0
NAME_PATTERN=""
EXITED_CODE=""
FORCE=false
YES=false
PRUNE=false
VERBOSE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -l|--list)
            LIST_ONLY=true
            shift
            ;;
        -a|--all)
            REMOVE_ALL=true
            shift
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -n|--name)
            NAME_PATTERN="$2"
            shift 2
            ;;
        -e|--exited-code)
            EXITED_CODE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -y|--yes)
            YES=true
            shift
            ;;
        -p|--prune)
            PRUNE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Function to log verbose messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

# Function to get containers based on criteria
get_containers() {
    local filter_args=""
    
    # Base filter for stopped containers
    filter_args="--filter status=exited"
    
    # Add name pattern filter if specified
    if [ -n "$NAME_PATTERN" ]; then
        filter_args="$filter_args --filter name=$NAME_PATTERN"
    fi
    
    # Add exit code filter if specified
    if [ -n "$EXITED_CODE" ]; then
        filter_args="$filter_args --filter exited=$EXITED_CODE"
    fi
    
    # Get container IDs
    container_ids=$(docker ps -a $filter_args --format '{{.ID}}')
    
    # If days filter is specified, filter by time
    if [ "$DAYS" -gt 0 ]; then
        log "Filtering containers stopped for more than $DAYS days..."
        current_time=$(date +%s)
        filtered_ids=""
        
        for id in $container_ids; do
            # Get container's exit time
            finished=$(docker inspect --format '{{.State.FinishedAt}}' $id)
            
            # Convert to a format that date can handle
            simplified_finished=$(echo $finished | sed 's/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\..*/\1/')
            
            # Convert to Unix timestamp
            finished_at=$(date -d "$simplified_finished" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$simplified_finished" +%s 2>/dev/null)
            
            # Calculate difference in days
            diff=$(( (current_time - finished_at) / 86400 ))
            
            if [ $diff -gt $DAYS ]; then
                if [ -z "$filtered_ids" ]; then
                    filtered_ids="$id"
                else
                    filtered_ids="$filtered_ids $id"
                fi
            fi
        done
        
        container_ids="$filtered_ids"
    fi
    
    echo "$container_ids"
}

# Function to display container details
display_containers() {
    local container_ids="$1"
    
    if [ -z "$container_ids" ]; then
        echo "No containers found matching the criteria."
        return
    fi
    
    echo "Found the following containers:"
    echo "-------------------------------"
    printf "%-20s %-20s %-20s %-20s %-20s\n" "CONTAINER ID" "NAME" "IMAGE" "EXIT CODE" "STOPPED AT"
    
    for id in $container_ids; do
        name=$(docker inspect --format '{{.Name}}' $id | sed 's/^\///')
        image=$(docker inspect --format '{{.Config.Image}}' $id)
        exit_code=$(docker inspect --format '{{.State.ExitCode}}' $id)
        stopped_at=$(docker inspect --format '{{.State.FinishedAt}}' $id | sed 's/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).*/\1 \2/')
        
        printf "%-20s %-20s %-20s %-20s %-20s\n" "$id" "$name" "$image" "$exit_code" "$stopped_at"
    done
}

# Function to remove containers
remove_containers() {
    local container_ids="$1"
    local force_flag=""
    
    if [ -z "$container_ids" ]; then
        echo "No containers to remove."
        return
    fi
    
    if [ "$FORCE" = true ]; then
        force_flag="-f"
    fi
    
    # Ask for confirmation unless --yes is specified
    if [ "$YES" != true ]; then
        read -p "Are you sure you want to remove these containers? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi
    
    # Remove containers
    for id in $container_ids; do
        name=$(docker inspect --format '{{.Name}}' $id | sed 's/^\///')
        echo "Removing container $name ($id)..."
        docker rm $force_flag $id
    done
    
    echo "Container cleanup completed."
}

# Main logic
if [ "$PRUNE" = true ]; then
    if [ "$YES" = true ]; then
        echo "Running docker system prune..."
        docker system prune -f
    else
        docker system prune
    fi
    exit 0
fi

# Get containers based on criteria
if [ "$REMOVE_ALL" = true ]; then
    log "Getting all stopped containers..."
    CONTAINER_IDS=$(docker ps -a --filter status=exited --format '{{.ID}}')
else
    log "Getting containers based on specified criteria..."
    CONTAINER_IDS=$(get_containers)
fi

# Display containers
display_containers "$CONTAINER_IDS"

# Remove containers if not in list-only mode
if [ "$LIST_ONLY" != true ]; then
    remove_containers "$CONTAINER_IDS"
fi

exit 0