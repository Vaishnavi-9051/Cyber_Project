#!/bin/bash
# Enhanced attack detection functions

# Feature 1: Global Failure-Rate Monitoring
detect_global_failure_rate() {
    local recent_total=$(grep "Failed password" "$TEMP_NEW_ENTRIES" | wc -l)
    
    if (( recent_total > GLOBAL_FAILURE_THRESHOLD )); then
        log "ALERT" "High SSH failure rate ($recent_total failures) - possible distributed attack"
        
        send_global_alert "High SSH failure rate detected: $recent_total failures. Possible IP rotation attack."
        
        # Optional: Temporary SSH lockdown (commented for safety)
        # log "ALERT" "Activating temporary SSH lockdown for 5 minutes"
        # iptables -I INPUT -p tcp --dport 22 -j DROP
        # sleep 300
        # iptables -D INPUT -p tcp --dport 22 -j DROP
        # log "INFO" "SSH lockdown ended"
        
        # Alternative: Just block the worst offenders more aggressively
        if (( recent_total > $((GLOBAL_FAILURE_THRESHOLD * 2)) )); then
            log "ALERT" "Critical failure rate - activating aggressive blocking"
            local aggressive_threshold=$((THRESHOLD - 1))
            awk '{print $1}' "$TEMP_IPS" | sort | uniq -c | \
            while read -r count ip; do
                if [[ $count -ge aggressive_threshold ]] && ! is_whitelisted "$ip" && ! is_ip_blocked "$ip"; then
                    block_ip "$ip"
                    add_to_blocked_db "$ip" "$count" "Global Rate Alert"
                fi
            done
        fi
    fi
}

# Feature 2: Username-Based Correlation
detect_username_correlation() {
    local user_ip_threshold=5
    local short_window=300  # 5 minutes
    local now_ts=$(date +%s)
    local cutoff_ts=$((now_ts - short_window))
    
    # Extract username-IP pairs from recent entries
    awk '/Failed password/ {
        for(i=1;i<=NF;i++) {
            if($i=="for") {user=$(i+1)}
            if($i=="from") {ip=$(i+1)}
        }
        print user, ip
    }' "$TEMP_NEW_ENTRIES" | tr -d '()' > /tmp/ip_user_list.tmp
    
    # Analyze for username correlation
    awk '
    {
        users[$1]++
        ip_list[$1] = ip_list[$1] " " $2
        unique_ips[$1][$2] = 1
    }
    END {
        for (user in users) {
            unique_count = 0
            for (ip in unique_ips[user]) unique_count++
            if (unique_count >= 5) {
                print user, unique_count, ip_list[user]
            }
        }
    }' /tmp/ip_user_list.tmp | while read -r user count ips; do
        log "ALERT" "User $user targeted by $count unique IPs - possible distributed attack"
        send_global_alert "User $user under distributed brute-force by $count different IPs"
        
        # Block all attacking IPs for this user
        for ip in $ips; do
            ip_clean=$(echo "$ip" | tr -d ' ')
            if [[ -n "$ip_clean" ]] && ! is_whitelisted "$ip_clean" && ! is_ip_blocked "$ip_clean"; then
                block_ip "$ip_clean"
                add_to_blocked_db "$ip_clean" "$count" "Username Correlation: $user"
                log "INFO" "Blocked IP $ip_clean for targeting user $user from multiple sources"
            fi
        done
    done
}

# Feature 3: Global Connection Ratio Alert
detect_connection_ratio() {
    local fails=$(grep "Failed password" "$TEMP_NEW_ENTRIES" | wc -l)
    local success=$(grep "Accepted password" "$TEMP_NEW_ENTRIES" | wc -l)
    local total=$((fails + success))
    
    if (( total > 10 )); then  # Only check if we have meaningful activity
        local fail_rate=$((fails * 100 / total))
        
        if (( fail_rate > CONNECTION_RATIO_THRESHOLD )); then
            log "ALERT" "Abnormal SSH activity: $fail_rate% failures ($fails fails, $success successes)"
            send_global_alert "SSH abnormal: $fail_rate% failed logins ($fails/$total)"
            
            # Increase sensitivity when failure ratio is very high
            if (( fail_rate > 95 )); then
                log "ALERT" "Critical failure ratio - activating enhanced protection"
                local enhanced_threshold=$((THRESHOLD - 1))
                awk '{print $1}' "$TEMP_IPS" | sort | uniq -c | \
                while read -r count ip; do
                    if [[ $count -ge enhanced_threshold ]] && ! is_whitelisted "$ip" && ! is_ip_blocked "$ip"; then
                        block_ip "$ip"
                        add_to_blocked_db "$ip" "$count" "High Failure Ratio"
                    fi
                done
            fi
        fi
    fi
}

# Feature 4: Extended Time Window Detection
detect_extended_window_attacks() {
    local long_window=3600  # 1 hour
    local extended_threshold=300  # 300 failures in 1 hour
    
    # Get current hour and previous hour for log filtering
    local current_hour=$(date '+%b %_d %H')
    local previous_hour=$(date -d '1 hour ago' '+%b %_d %H')
    
    # Count failures in the last hour
    local recent_fails=$(grep "Failed password" "$LOG_FILE" | \
    grep -E "($current_hour|$previous_hour)" | wc -l)
    
    if (( recent_fails > extended_threshold )); then
        log "ALERT" "Sustained high SSH failure rate: $recent_fails attempts in last hour"
        send_global_alert "Sustained SSH attack: $recent_fails failures in 1 hour - ongoing distributed attack"
        
        # Log this for historical analysis
        echo "$(date): Sustained attack detected - $recent_fails failures/hour" >> "$SCRIPT_DIR/logs/sustained_attacks.log"
        
        # Optional: Increase blocking threshold for sustained attacks
        if (( recent_fails > $((extended_threshold * 2)) )); then
            log "ALERT" "Very high sustained rate - activating persistent protection"
            PERSISTENT_FILE="$SCRIPT_DIR/persistent_protection.active"
            touch "$PERSISTENT_FILE"
            send_global_alert "CRITICAL: Very high sustained attack rate - persistent protection activated"
        fi
    fi
    
    # Check if we should deactivate persistent protection
    if [[ -f "$SCRIPT_DIR/persistent_protection.active" ]]; then
        local recent_fails_lower=$(grep "Failed password" "$LOG_FILE" | \
        grep "$current_hour" | wc -l)
        
        if (( recent_fails_lower < 50 )); then  # Attack has subsided
            log "INFO" "Attack subsided - deactivating persistent protection"
            rm -f "$SCRIPT_DIR/persistent_protection.active"
        fi
    fi
}
