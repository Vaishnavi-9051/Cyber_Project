uninstall.sh :  #!/bin/bash
# IP Blocker Uninstall Script
# Safely removes the IP blocker system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.conf"

# Load configuration if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}IP Blocker Uninstaller${NC}"
echo "==============================="

# Safety confirmation
read -p "Are you sure you want to uninstall IP Blocker? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo -e "${YELLOW}Starting uninstall process...${NC}"

# Step 1: Stop any running instances
echo "1. Stopping running processes..."
pkill -f "ip_blocker.sh" 2>/dev/null && echo -e "${GREEN}✓ Stopped running processes${NC}" || echo "No running processes found"

# Step 2: Remove from cron
echo "2. Removing from crontab..."
crontab -l 2>/dev/null | grep -v "ip_blocker.sh" | crontab - && echo -e "${GREEN}✓ Removed from crontab${NC}"

# Step 3: Unblock all IPs blocked by this system
echo "3. Unblocking IPs..."
if [[ -f "$BLOCKED_DB" ]]; then
    blocked_count=0
    while read -r line; do
        ip=$(echo "$line" | awk '{print $1}')
        if [[ -n "$ip" ]]; then
            ufw delete deny from "$ip" 2>/dev/null
            ((blocked_count++))
        fi
    done < "$BLOCKED_DB"
    echo -e "${GREEN}✓ Unblocked $blocked_count IPs${NC}"
fi

# Step 4: Remove application files
echo "4. Removing application files..."
if [[ -d "$SCRIPT_DIR" ]]; then
    # Create backup of configuration
    backup_dir="/tmp/ip_blocker_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$SCRIPT_DIR" "$backup_dir/" 2>/dev/null && echo -e "${GREEN}✓ Backup created: $backup_dir${NC}"
    
    # Remove main directory
    rm -rf "$SCRIPT_DIR" && echo -e "${GREEN}✓ Removed application directory${NC}"
else
    echo -e "${YELLOW}⚠ Application directory not found${NC}"
fi

# Step 5: Remove temporary files
echo "5. Cleaning temporary files..."
rm -f /tmp/ip_blocker_*.tmp /tmp/ip_user_list.tmp && echo -e "${GREEN}✓ Cleaned temporary files${NC}"

# Step 6: Final verification
echo "6. Final verification..."
if [[ ! -d "$SCRIPT_DIR" ]]; then
    echo -e "${GREEN}🎉 IP Blocker successfully uninstalled!${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC}"
    echo "- Configuration backup saved to: $backup_dir"
    echo "- Manual ufw rules were preserved"
    echo "- System logs were not modified"
else
    echo -e "${RED}❌ Uninstall may not have completed fully${NC}"
    echo "Please manually check: $SCRIPT_DIR"
fi

echo ""
echo -e "${YELLOW}Thank you for using IP Blocker!${NC}"
