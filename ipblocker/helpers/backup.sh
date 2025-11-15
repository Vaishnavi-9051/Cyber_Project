#!/bin/bash
# Backup functions for IP Blocker

perform_backup() {
    local backup_dir="/opt/ip_blocker/backup/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log "INFO" "Starting backup to $backup_dir"
    
    # Backup configuration files
    cp /opt/ip_blocker/config.conf "$backup_dir/config.backup.$(date +%Y%m%d)"
    cp /opt/ip_blocker/whitelist.conf "$backup_dir/whitelist.backup.$(date +%Y%m%d)"
    
    # Backup data files
    cp /opt/ip_blocker/blocked_ips.db "$backup_dir/blocked_ips.backup.$(date +%Y%m%d)"
    cp /opt/ip_blocker/last_position.txt "$backup_dir/last_position.backup.$(date +%Y%m%d)"
    
    # Backup logs
    cp /opt/ip_blocker/logs/ip_blocker.log "$backup_dir/ip_blocker.log.backup.$(date +%Y%m%d)"
    
    # Generate backup report
    generate_backup_report "$backup_dir"
    
    # Clean up old backups
    cleanup_old_backups
    
    log "INFO" "Backup completed: $backup_dir"
    send_backup_notification "$backup_dir" "SUCCESS"
}

cleanup_old_backups() {
    local backup_dir="/opt/ip_blocker/backup"
    local retention_days=7
    
    find "$backup_dir" -name "backup_*" -type d -mtime +$retention_days -exec rm -rf {} \; 2>/dev/null
    
    log "INFO" "Cleaned up backups older than $retention_days days"
}

# Auto-backup if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "/opt/ip_blocker/config.conf"
    source "/opt/ip_blocker/helpers/logger.sh"
    source "/opt/ip_blocker/helpers/reporter.sh"
    perform_backup
fi
