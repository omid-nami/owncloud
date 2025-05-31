#!/bin/bash

# Script to clean up OwnCloud user directories
# This will delete all contents but preserve the user directories themselves

OWNCLOUD_PATH="/var/www/owncloud"
# Set the path to your OwnCloud data directory
OC_DATA_DIR="$OWNCLOUD_PATH/data"
# Path to occ command
OCC_CMD="$OWNCLOUD_PATH/occ"

# Log file location
LOG_FILE="/var/log/owncloud-cleanup.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

log "Starting OwnCloud cleanup process"

# Find all user directories and clean them
if [ -d "$OC_DATA_DIR" ]; then
    find "$OC_DATA_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "*appdata*" | while read -r user_dir; do
        username=$(basename "$user_dir")
        # Skip system directories
        if [[ "$username" =~ ^[a-zA-Z0-9_@.\-]+$ ]]; then
            log "Cleaning up user: $username"
            # Remove all contents but keep the directory itself
            find "$user_dir/files" -mindepth 1 -exec rm -rf {} + 2>/dev/null || true
            # Recreate the files directory if it was removed
            mkdir -p "$user_dir/files"
            # Set proper permissions
            chown -R www-data:www-data "$user_dir"
            chmod 750 "$user_dir"
            chmod 770 "$user_dir/files"
            
            # Clean up database entries for the user
            log "Cleaning up database entries for user: $username"
            sudo -u www-data php "$OCC_CMD" files:cleanup "$username" --quiet || log "Warning: Could not clean up database for user $username"
        fi
    done
    log "Cleanup completed successfully"
else
    log "ERROR: OwnCloud data directory not found at $OC_DATA_DIR"
    exit 1
fi
