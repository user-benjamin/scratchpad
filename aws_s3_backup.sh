#!/bin/bash

# aws_s3_backup.sh - Script to backup a directory to AWS S3
# 
# This script backs up a specified directory to an AWS S3 bucket.
# It supports various options including compression, encryption, and incremental backups.

set -e

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Backup a directory to AWS S3."
    echo
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -s, --source DIR           Source directory to backup (required)"
    echo "  -b, --bucket BUCKET        S3 bucket name (required)"
    echo "  -p, --prefix PREFIX        S3 prefix/path inside the bucket (default: backups/)"
    echo "  -c, --compress             Compress the backup using tar and gzip"
    echo "  -e, --encrypt              Encrypt the backup using AWS SSE-S3 encryption"
    echo "  -i, --incremental          Perform incremental backup (sync only changed files)"
    echo "  -d, --date-prefix          Add date prefix to backup files (YYYY-MM-DD)"
    echo "  -r, --retention DAYS       Delete backups older than DAYS days"
    echo "  -l, --log FILE             Log output to FILE"
    echo "  -v, --verbose              Enable verbose output"
    echo "  -n, --dry-run              Show what would be uploaded without actually uploading"
    echo "  -P, --profile PROFILE      Use specific AWS profile from ~/.aws/credentials"
    echo
    echo "Examples:"
    echo "  $0 --source /home/user/data --bucket my-backups"
    echo "  $0 --source /var/www --bucket my-backups --prefix websites/ --compress --encrypt"
    echo "  $0 --source /etc --bucket my-backups --date-prefix --retention 30"
    exit 1
}

# Initialize variables
SOURCE_DIR=""
BUCKET_NAME=""
PREFIX="backups/"
COMPRESS=false
ENCRYPT=false
INCREMENTAL=false
DATE_PREFIX=false
RETENTION_DAYS=0
LOG_FILE=""
VERBOSE=false
DRY_RUN=false
AWS_PROFILE=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -b|--bucket)
            BUCKET_NAME="$2"
            shift 2
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -e|--encrypt)
            ENCRYPT=true
            shift
            ;;
        -i|--incremental)
            INCREMENTAL=true
            shift
            ;;
        -d|--date-prefix)
            DATE_PREFIX=true
            shift
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -P|--profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Function to log messages
log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="$timestamp - $1"
    
    echo "$message"
    
    if [ -n "$LOG_FILE" ]; then
        echo "$message" >> "$LOG_FILE"
    fi
}

# Function to log verbose messages
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log "$1"
    fi
}

# Check required parameters
if [ -z "$SOURCE_DIR" ]; then
    log "Error: Source directory is required"
    usage
fi

if [ -z "$BUCKET_NAME" ]; then
    log "Error: S3 bucket name is required"
    usage
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log "Error: Source directory '$SOURCE_DIR' does not exist"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Set AWS profile if specified
AWS_CMD="aws"
if [ -n "$AWS_PROFILE" ]; then
    AWS_CMD="aws --profile $AWS_PROFILE"
fi

# Check if the bucket exists
log_verbose "Checking if bucket '$BUCKET_NAME' exists..."
if ! $AWS_CMD s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
    log "Error: Bucket '$BUCKET_NAME' does not exist or you don't have access to it"
    exit 1
fi

# Set up backup path and filename
CURRENT_DATE=$(date "+%Y-%m-%d")
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
BACKUP_NAME=$(basename "$SOURCE_DIR")

if [ "$DATE_PREFIX" = true ]; then
    S3_PATH="$PREFIX$CURRENT_DATE/$BACKUP_NAME"
else
    S3_PATH="$PREFIX$BACKUP_NAME"
fi

# Prepare AWS S3 command options
S3_OPTS=""

if [ "$VERBOSE" = true ]; then
    S3_OPTS="$S3_OPTS --debug"
fi

if [ "$DRY_RUN" = true ]; then
    S3_OPTS="$S3_OPTS --dryrun"
fi

if [ "$ENCRYPT" = true ]; then
    S3_OPTS="$S3_OPTS --sse AES256"
fi

# Perform backup
log "Starting backup of '$SOURCE_DIR' to 's3://$BUCKET_NAME/$S3_PATH'..."

if [ "$COMPRESS" = true ]; then
    # Compressed backup using tar and gzip
    TEMP_FILE="/tmp/backup_${TIMESTAMP}.tar.gz"
    log_verbose "Creating compressed archive at '$TEMP_FILE'..."
    
    tar -czf "$TEMP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
    
    log_verbose "Uploading compressed archive to S3..."
    $AWS_CMD s3 cp $S3_OPTS "$TEMP_FILE" "s3://$BUCKET_NAME/$S3_PATH.tar.gz"
    
    # Clean up temporary file
    log_verbose "Cleaning up temporary file..."
    rm -f "$TEMP_FILE"
else
    if [ "$INCREMENTAL" = true ]; then
        # Incremental backup using sync
        log_verbose "Performing incremental backup using sync..."
        $AWS_CMD s3 sync $S3_OPTS "$SOURCE_DIR" "s3://$BUCKET_NAME/$S3_PATH"
    else
        # Full backup using cp with recursive option
        log_verbose "Performing full backup..."
        $AWS_CMD s3 cp $S3_OPTS --recursive "$SOURCE_DIR" "s3://$BUCKET_NAME/$S3_PATH"
    fi
fi

# Handle retention policy
if [ "$RETENTION_DAYS" -gt 0 ]; then
    log "Applying retention policy: removing backups older than $RETENTION_DAYS days..."
    
    # Calculate the cutoff date
    CUTOFF_DATE=$(date -d "$CURRENT_DATE -$RETENTION_DAYS days" "+%Y-%m-%d" 2>/dev/null || date -v-"$RETENTION_DAYS"d "+%Y-%m-%d" 2>/dev/null)
    
    if [ -n "$CUTOFF_DATE" ]; then
        log_verbose "Cutoff date: $CUTOFF_DATE"
        
        # List objects in the bucket with the prefix
        OBJECTS=$($AWS_CMD s3 ls "s3://$BUCKET_NAME/$PREFIX" --recursive)
        
        # Process each object
        echo "$OBJECTS" | while read -r line; do
            # Extract date from the object key
            if [[ $line =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
                OBJECT_DATE="${BASH_REMATCH[1]}"
                OBJECT_KEY=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*//')
                
                # Compare dates
                if [[ "$OBJECT_DATE" < "$CUTOFF_DATE" ]]; then
                    log_verbose "Removing old backup: $OBJECT_KEY (date: $OBJECT_DATE)"
                    if [ "$DRY_RUN" = false ]; then
                        $AWS_CMD s3 rm "s3://$BUCKET_NAME/$OBJECT_KEY"
                    else
                        log_verbose "Dry run: would remove s3://$BUCKET_NAME/$OBJECT_KEY"
                    fi
                fi
            fi
        done
    else
        log "Warning: Could not calculate cutoff date for retention policy"
    fi
fi

log "Backup completed successfully"
exit 0