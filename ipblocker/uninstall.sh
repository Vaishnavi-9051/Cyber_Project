#!/bin/bash
# Enhanced IP Blocker Uninstall Script
# Safe removal from /opt/ipblocker

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=================================${NC}"
echo -e "${YELLOW}   Enhanced IP Blocker Uninstall${NC}"
echo -e "${YELLOW}=================================${NC}"

# Safety check - only allow uninstall from /opt/ipblocker
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPECTED_DIR="/opt/ipblocker"

if [[ "$CURRENT_DIR" != "$EXPECTED_DIR" ]]; then
    echo -e "${RED}❌ ERROR: Uninstall must be run from $EXPECTED_DIR${NC}"
    echo -e "${YELLOW}➡  Use: sudo $EXPECTED_DIR/uninstall.sh${NC}"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ ERROR: Please run as root${NC}"
    echo -e "${YELLOW}➡  Use: sudo $0${NC}"
    exit 1
fi

# Safety confirmation
echo ""
echo -e "${YELLOW}⚠  WARNING: This will completely remove IP Blocker${NC}"
echo -e "${YELLOW}   All configurations and data will be backed up then removed${NC}"
echo ""
read -p "Are you sure you want to continue? (type 'YES' to confirm): " -r
if [[ ! $REPLY == "YES" ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting uninstall process...${NC}"

# Step 1: Stop any running instances
echo "1️⃣ Stopping running processes..."
pkill -f "ipblocker/ip_blocker.sh" 2>/dev/null
sleep 2
echo -e "   ${GREEN}✔ Processes stopped${NC}"

# Step 2: Remove from cron
echo "2️⃣ Removing from crontab..."
crontab -l 2>/dev/null | grep -v "ipblocker" | crontab -
echo -e "   ${GREEN}✔ Crontab entries removed${NC}"

# Step 3: Unblock all IPs blocked by this system
echo "3️⃣ Unblocking IPs..."
if [[ -f "$CURRENT_DIR/blocked_ips.db" ]]; then
    blocked_count=0
    while read -r line; do
        ip=$(echo "$line" | awk '{print $1}')
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ufw delete deny from "$ip" 2>/dev/null
            ((blocked_count++))
        fi
    done < "$CURRENT_DIR/blocked_ips.db"
    echo -e "   ${GREEN}✔ Unblocked $blocked_count IPs${NC}"
else
    echo -e "   ${YELLOW}⚠ No blocked IPs database found${NC}"
fi

# Step 4: Create comprehensive backup
echo "4️⃣ Creating backup..."
BACKUP_DIR="/tmp/ipblocker_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "$CURRENT_DIR" "$BACKUP_DIR/" 2>/dev/null
echo -e "   ${GREEN}✔ Backup created: $BACKUP_DIR${NC}"

# Step 5: Remove application files
echo "5️⃣ Removing application files..."
rm -rf "$CURRENT_DIR" && \
echo -e "   ${GREEN}✔ Application directory removed${NC}" || \
echo -e "   ${RED}❌ Error removing directory${NC}"

# Step 6: Clean temporary files
echo "6️⃣ Cleaning temporary files..."
rm -f /tmp/ip_blocker_*.tmp /tmp/ip_user_list.tmp
echo -e "   ${GREEN}✔ Temporary files cleaned${NC}"

# Final verification
echo ""
echo "7️⃣ Final verification..."
if [[ ! -d "$CURRENT_DIR" ]]; then
    echo -e "${GREEN}🎉 IP Blocker successfully uninstalled!${NC}"
    echo ""
    echo -e "${YELLOW}📁 Backup location:${NC}"
    echo "   $BACKUP_DIR"
    echo ""
    echo -e "${YELLOW}Note:${NC}"
    echo "   - Manual UFW rules were preserved"
    echo "   - System logs were not modified"
    echo "   - Configuration backup saved above"
else
    echo -e "${RED}❌ Uninstall may not have completed fully${NC}"
    echo "   Please check: $CURRENT_DIR"
fi

echo ""
echo -e "${YELLOW}Thank you for using Enhanced IP Blocker!${NC}" 
