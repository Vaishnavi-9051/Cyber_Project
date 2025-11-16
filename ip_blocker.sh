#!/bin/bash

# Enhanced IP Blocker with Advanced Attack Detection
# Auto-detects installation directory and includes all security features

# Auto-detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
CONFIG_FILE="$SCRIPT_DIR/config.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ ERROR: Config file not found at $CONFIG_FILE"
    echo "➡  Please run setup.sh first"
    exit 1
fi

source "$CONFIG_FILE"
source "$SCRIPT_DIR/helpers/logger.sh"
source "$SCRIPT_DIR/helpers/notifier.sh"
source "$SCRIPT_DIR/helpers/reporter.sh"
source "$SCRIPT_DIR/helpers/attack_detector.sh"

# Global variables
RECENT_BLOCKED=0
RECENT_WHITELIST=0
RECENT_EXISTING=0

# Initialize with path safety
init() {
    # Create log directory and file
    mkdir -p "$(dirname "$APP_LOG")"
    touch "$APP_LOG"
    chmod 644 "$APP_LOG"
    
    log "INFO" "IP Blocker started from: $SCRIPT_DIR"
    log "INFO" "IP Blocker started - $(date)"
    
    # Create necessary files with full paths
    mkdir -p "$SCRIPT_DIR/logs"
    touch "$BLOCKED_DB" "$WHITELIST_FILE" "$LAST_POSITION_FILE" "$USER_CORRELATION_DB"
    
    # Check dependencies
    check_dependencies
}

# Check required tools
check_dependencies() {
    local deps=("grep" "awk" "ufw" "tail" "stat" "date")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "ERROR" "Dependency missing: $dep"
            exit 1
        fi
    done
    log "INFO" "All dependencies checked"
}

# Analyze new log entries since last run
analyze_logs() {
    local current_size last_position
    
    current_size=$(get_file_size "$LOG_FILE")
    last_position=$(get_last_position)
    
    if [[ $last_position -eq $current_size ]]; then
        log "INFO" "No new log entries"
        return 0
    fi
    
    if [[ $last_position -gt $current_size ]]; then
        # Log file was rotated
        log "INFO" "Log file rotated, analyzing from beginning"
        last_position=0
    fi
    
    # Extract new content
    extract_new_entries "$last_position" "$current_size"
    update_last_position "$current_size"
}

# Extract new log entries
extract_new_entries() {
    local last_pos=$1 current_size=$2
    
    tail -c +$((last_pos + 1)) "$LOG_FILE" > "$TEMP_NEW_ENTRIES"
    
    # Extract failed login attempts with IP and username
    grep "Failed password\|authentication failure" "$TEMP_NEW_ENTRIES" | \
    awk '
    /Failed password/ {
        ip = ""
        user = ""
        for(i=1;i<=NF;i++) {
            if($i == "from") {
                ip = $(i+1)
            }
            if($i == "for") {
                user = $(i+1)
            }
        }
        if(ip != "" && user != "") {
            print ip, user
        }
    }
    /authentication failure/ {
        ip = ""
        for(i=1;i<=NF;i++) {
            if($i == "rhost") {
                ip = $(i+1)
                break
            }
        }
        if(ip != "") {
            print ip, "unknown"
        }
    }' | tr -d '()' > "$TEMP_IPS"
    
    local extracted_count=$(wc -l < "$TEMP_IPS" 2>/dev/null || echo 0)
    log "INFO" "Extracted $extracted_count new failed attempts"
}

# Count attempts and identify malicious IPs
identify_malicious_ips() {
    # Count attempts per IP
    awk '{print $1}' "$TEMP_IPS" | sort | uniq -c | while read -r count ip; do
        if [[ $count -ge $THRESHOLD ]]; then
            echo "$ip $count"
        fi
    done > "$TEMP_MALICIOUS"
}

# Block malicious IPs
block_malicious_ips() {
    local blocked_count=0 skipped_whitelist=0 skipped_existing=0
    
    while read -r ip_count; do
        [[ -z "$ip_count" ]] && continue
        
        ip=$(echo "$ip_count" | awk '{print $1}')
        count=$(echo "$ip_count" | awk '{print $2}')
        
        # Validate IP format
        if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log "DEBUG" "Skipping invalid IP: $ip"
            continue
        fi
        
        # Check if already blocked
        if is_ip_blocked "$ip"; then
            log "DEBUG" "IP already blocked: $ip"
            ((skipped_existing++))
            continue
        fi
        
        # Check if whitelisted
        if is_whitelisted "$ip"; then
            log "INFO" "Skipped whitelisted IP: $ip ($count attempts)"
            ((skipped_whitelist++))
            continue
        fi
        
        # Block the IP
        if block_ip "$ip"; then
            log "INFO" "Blocked IP: $ip ($count attempts)"
            add_to_blocked_db "$ip" "$count" "Threshold Exceeded"
            send_notification "BLOCKED" "$ip" "$count"
            ((blocked_count++))
        else
            log "ERROR" "Failed to block IP: $ip"
        fi
        
    done < "$TEMP_MALICIOUS"
    
    # Update report
    update_report "$blocked_count" "$skipped_whitelist" "$skipped_existing"
}

# Check if IP is already blocked
is_ip_blocked() {
    local ip=$1
    [[ -f "$BLOCKED_DB" ]] && grep -q "^$ip " "$BLOCKED_DB"
}

# Check if IP is whitelisted
is_whitelisted() {
    local ip=$1
    if [[ -f "$WHITELIST_FILE" ]]; then
        grep -q "^$ip$" "$WHITELIST_FILE" || \
        grep -q "^$ip/" "$WHITELIST_FILE"
    else
        return 1
    fi
}

# Block IP using ufw
block_ip() {
    local ip=$1
    ufw deny from "$ip" > /dev/null 2>&1
    return $?
}

# Add to blocked database
add_to_blocked_db() {
    local ip=$1 count=$2 reason=$3
    echo "$ip $count $(date '+%Y-%m-%d %H:%M:%S') '$reason'" >> "$BLOCKED_DB"
}

# File size helper
get_file_size() {
    stat -c %s "$1" 2>/dev/null || echo 0
}

# Position tracking
get_last_position() {
    [[ -f "$LAST_POSITION_FILE" ]] && cat "$LAST_POSITION_FILE" || echo 0
}

update_last_position() {
    echo "$1" > "$LAST_POSITION_FILE"
}

# Run all attack detection features
run_attack_detection() {
    log "INFO" "Running advanced attack detection..."
    
    # Feature 1: Global Failure-Rate Monitoring
    detect_global_failure_rate
    
    # Feature 2: Username-Based Correlation
    detect_username_correlation
    
    # Feature 3: Global Connection Ratio Alert
    detect_connection_ratio
    
    # Feature 4: Extended Time Window Detection
    detect_extended_window_attacks
}

# Perform backup if enabled
perform_scheduled_backup() {
    if [[ "$BACKUP_ENABLED" == "true" ]] && [[ -f "$SCRIPT_DIR/helpers/backup.sh" ]]; then
        log "INFO" "Running scheduled backup..."
        source "$SCRIPT_DIR/helpers/backup.sh"
        perform_backup
    fi
}

# Cleanup temporary files
cleanup() {
    rm -f "$TEMP_NEW_ENTRIES" "$TEMP_IPS" "$TEMP_MALICIOUS" /tmp/ip_user_list.tmp
    log "INFO" "IP Blocker finished - $(date)"
}

# Main execution flow
main() {
    log "INFO" "=== IP Blocker Execution Started ==="
    
    if ! init; then
        log "ERROR" "Initialization failed"
        exit 1
    fi
    
    # Analyze authentication logs
    analyze_logs
    
    if [[ -s "$TEMP_IPS" ]]; then
        log "INFO" "Processing $(wc -l < "$TEMP_IPS") failed login attempts"
        
        # Run enhanced attack detection
        run_attack_detection
        
        # Identify and block malicious IPs
        identify_malicious_ips
        
        if [[ -s "$TEMP_MALICIOUS" ]]; then
            log "INFO" "Found $(wc -l < "$TEMP_MALICIOUS") IPs exceeding threshold"
            block_malicious_ips
        else
            log "INFO" "No IPs exceeded blocking threshold"
        fi
        
        # Generate report
        generate_report
    else
        log "INFO" "No new failed login attempts found"
    fi
    
    # Perform backup if it's time (e.g., first run of the day)
    local current_hour=$(date +%H)
    if [[ "$current_hour" == "00" ]]; then
        perform_scheduled_backup
    fi
    
    cleanup
}

# Handle signals for graceful shutdown
trap 'log "INFO" "Script interrupted"; cleanup; exit 1' INT TERM
trap cleanup EXIT

# Run main function
main "$@"
