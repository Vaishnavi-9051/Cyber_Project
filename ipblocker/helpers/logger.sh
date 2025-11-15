#!/bin/bash
# Logging functions

# Ensure log directory exists
ensure_log_dir() {
    local log_dir=$(dirname "$APP_LOG")
    mkdir -p "$log_dir"
    touch "$APP_LOG"
    chmod 644 "$APP_LOG"
}

log() {
    local level=$1 message=$2 timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log file exists
    ensure_log_dir
    
    # Write to log file
    echo "[$timestamp] $level: $message" >> "$APP_LOG"
    
    # Also print to console if interactive
    if [[ -t 0 ]]; then
        echo "[$timestamp] $level: $message"
    fi
}

# Log with different levels
log_info() {
    log "INFO" "$1"
}

log_error() {
    log "ERROR" "$1"
}

log_debug() {
    log "DEBUG" "$1"
}

log_alert() {
    log "ALERT" "$1"
}
