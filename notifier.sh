#!/bin/bash
# Enhanced notification functions

send_notification() {
    local action=$1 ip=$2 attempts=$3
    local message="IP Blocker - $action: $ip (Attempts: $attempts) at $(date)"
    
    # System notification
    echo "$message" >> "$APP_LOG"
    
    # Enhanced logging for different actions
    case $action in
        "BLOCKED")
            echo "SECURITY: Blocked malicious IP $ip after $attempts attempts" >> "$APP_LOG"
            ;;
        "GLOBAL_ALERT")
            echo "CRITICAL: $message" >> "$APP_LOG"
            ;;
    esac
}

send_global_alert() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Enhanced global alert logging
    echo "=== GLOBAL SECURITY ALERT ===" >> "$APP_LOG"
    echo "TIME: $timestamp" >> "$APP_LOG"
    echo "ALERT: $message" >> "$APP_LOG"
    echo "=============================" >> "$APP_LOG"
    
    # Console alert if interactive
    if [[ -t 0 ]]; then
        echo "🚨 GLOBAL ALERT: $message"
    fi
    
    # Optional desktop notification
    if command -v notify-send &> /dev/null && [[ -n "$DISPLAY" ]]; then
        notify-send -u critical "IP Blocker Global Alert" "$message" -t 10000
    fi
    
    # Email notification if enabled
    if [[ "$SEND_EMAIL_ALERTS" == "true" ]] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "IP Blocker Global Alert" "$EMAIL_RECIPIENT"
    fi
}

# Backup notification
send_backup_notification() {
    local backup_file=$1 result=$2
    local message="Backup $result: $backup_file"
    
    log "INFO" "$message"
    
    if [[ "$result" == "SUCCESS" ]]; then
        echo "BACKUP: $message" >> "$APP_LOG"
    else
        echo "BACKUP_ERROR: $message" >> "$APP_LOG"
    fi
}
