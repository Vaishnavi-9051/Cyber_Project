#!/bin/bash
# Reporting functions

generate_report() {
    local total_blocked skipped_whitelist skipped_existing
    
    total_blocked=$(wc -l < "$BLOCKED_DB" 2>/dev/null || echo 0)
    
    log "INFO" "=== BLOCKING REPORT ==="
    log "INFO" "Total blocked IPs: $total_blocked"
    log "INFO" "Recent action - Blocked: $RECENT_BLOCKED, Whitelisted: $RECENT_WHITELIST, Existing: $RECENT_EXISTING"
    
    # Generate detailed report file
    generate_detailed_report
}

update_report() {
    local blocked=$1 whitelist=$2 existing=$3
    RECENT_BLOCKED=$blocked
    RECENT_WHITELIST=$whitelist
    RECENT_EXISTING=$existing
}

generate_detailed_report() {
    local report_file="/opt/ip_blocker/logs/daily_report_$(date +%Y%m%d).log"
    
    {
        echo "IP Blocker Daily Report - $(date)"
        echo "================================="
        echo "Total IPs Blocked: $(wc -l < "$BLOCKED_DB" 2>/dev/null || echo 0)"
        echo "Recent Session:"
        echo "  - Newly Blocked: $RECENT_BLOCKED"
        echo "  - Whitelisted: $RECENT_WHITELIST"
        echo "  - Already Blocked: $RECENT_EXISTING"
        echo ""
        echo "Last 10 Blocked IPs:"
        tail -10 "$BLOCKED_DB" 2>/dev/null | while read -r line; do
            echo "  - $line"
        done
    } > "$report_file"
    
    log "INFO" "Detailed report generated: $report_file"
}

# Backup reporting
generate_backup_report() {
    local backup_dir=$1
    local report_file="$backup_dir/backup_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "IP Blocker Backup Report"
        echo "========================"
        echo "Backup Time: $(date)"
        echo "Backup Directory: $backup_dir"
        echo ""
        echo "Files Backed Up:"
        find "$backup_dir" -type f -name ".backup." | while read -r file; do
            echo "  - $(basename "$file")"
        done
        echo ""
        echo "Current Statistics:"
        echo "  - Blocked IPs: $(wc -l < "$BLOCKED_DB" 2>/dev/null || echo 0)"
        echo "  - Whitelisted IPs: $(wc -l < "$WHITELIST_FILE" 2>/dev/null || echo 0)"
    } > "$report_file"
}
