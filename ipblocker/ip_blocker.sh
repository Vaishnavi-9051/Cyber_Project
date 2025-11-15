#!/bin/bash

# IP Blocker - Enhanced with attack pattern detection
# Main execution script

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.conf"
source "$SCRIPT_DIR/helpers/logger.sh"
source "$SCRIPT_DIR/helpers/notifier.sh"
source "$SCRIPT_DIR/helpers/reporter.sh"
source "$SCRIPT_DIR/helpers/attack_detector.sh"

# Initialize
init() {
    # Create log directory and file
    mkdir -p "$(dirname "$APP_LOG")"
    touch "$APP_LOG"
    chmod 644 "$APP_LOG"
    
    log "INFO" "IP Blocker started - $(date)"
    
    # Create necessary files
    mkdir -p "$SCRIPT_DIR/logs"
    touch "$BLOCKED_DB" "$WHITELIST_FILE" "$LAST_POSITION_FILE" "$USER_CORRELATION_DB"
    
    # Check dependencies
    check_dependencies
}

# Check required tools
check_dependencies() {
    local deps=("grep" "awk" "ufw" "tail" "stat" "date" "iptables")
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
    
    # Extract failed login attempts
    grep "Failed password\|authentication failure" "$TEMP_NEW_ENTRIES" | \
    awk '
    /Failed password/ {
        for(i=1;i<=NF;i++) {
            if($i == "from") {
                ip = $(i+1)
            }
            if($i == "for") {
                user = $(i+1)
            }
        }
        print ip, user
    }
    /authentication failure/ {
        for(i=1;i<=NF;i++) {
            if($i == "rhost") {
                ip = $(i+1)
                break
            }
        }
        print ip, "unknown"
    }' | tr -d '()' > "$TEMP_IPS"
    
    log "INFO" "Extracted $(wc -l < "$TEMP_IPS") new failed attempts"
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
    grep -q "^$ip " "$BLOCKED_DB"
}

# Check if IP is whitelisted
is_whitelisted() {
    local ip=$1
    grep -q "^$ip$" "$WHITELIST_FILE" || \
    grep -q "^$ip/" "$WHITELIST_FILE"
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

# Main execution flow
main() {
    init
    analyze_logs
    
    if [[ -s "$TEMP_IPS" ]]; then
        # Run enhanced attack detection
        detect_global_failure_rate
        detect_username_correlation
        detect_connection_ratio
        detect_extended_window_attacks
        
        identify_malicious_ips
        block_malicious_ips
        generate_report
    else
        log "INFO" "No malicious IPs found"
    fi
    
    cleanup
}

# Cleanup temporary files
cleanup() {
    rm -f "$TEMP_NEW_ENTRIES" "$TEMP_IPS" "$TEMP_MALICIOUS" /tmp/ip_user_list.tmp
    log "INFO" "IP Blocker finished - $(date)"
}

# Handle signals
trap cleanup EXIT

# Run main function
main "$@"
