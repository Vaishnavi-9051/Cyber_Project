#!/bin/bash
# Enhanced IP Blocker Setup Script
# Installs from your GitHub project folder into /opt/ipblocker

echo "================================="
echo "  Enhanced IP Blocker Setup"
echo "================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ ERROR: Please run as root"
    echo "➡  Use: sudo $0"
    exit 1
fi

# Auto-detect the directory where the setup.sh is located
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📁 Source Directory Detected:"
echo "   $SRC_DIR"
echo ""

# Target directory
TARGET_DIR="/opt/ipblocker"

echo "📦 Installing to: $TARGET_DIR"
echo ""

# Step 1: Create directory structure
echo "1️⃣ Creating directory structure..."
mkdir -p "$TARGET_DIR/helpers"
mkdir -p "$TARGET_DIR/logs"
mkdir -p "$TARGET_DIR/backup"
mkdir -p "$TARGET_DIR/docs"
echo "   ✔ Directories created"
echo ""

# Step 2: Copy core files
echo "2️⃣ Copying main files..."

cp "$SRC_DIR/ip_blocker.sh" "$TARGET_DIR/"
cp "$SRC_DIR/config.conf" "$TARGET_DIR/"
cp "$SRC_DIR/whitelist.conf" "$TARGET_DIR/"
cp "$SRC_DIR/setup.sh" "$TARGET_DIR/"
cp "$SRC_DIR/uninstall.sh" "$TARGET_DIR/"

echo "   ✔ Main files copied"
echo ""

# Step 3: Copy helper scripts
echo "3️⃣ Copying helper scripts..."

cp "$SRC_DIR/helpers/"*.sh "$TARGET_DIR/helpers/"

echo "   ✔ Helper scripts installed"
echo ""

# Step 4: Set permissions
echo "4️⃣ Setting executable permissions..."

chmod +x "$TARGET_DIR/ip_blocker.sh"
chmod +x "$TARGET_DIR/setup.sh"
chmod +x "$TARGET_DIR/uninstall.sh"
chmod +x "$TARGET_DIR/helpers/"*.sh

echo "   ✔ Permissions set"
echo ""

# Step 5: Create required data/log files
echo "5️⃣ Creating data files..."

touch "$TARGET_DIR/blocked_ips.db"
touch "$TARGET_DIR/user_correlation.db"
touch "$TARGET_DIR/last_position.txt"
touch "$TARGET_DIR/logs/ip_blocker.log"
touch "$TARGET_DIR/logs/sustained_attacks.log"

chmod 644 "$TARGET_DIR/logs/ip_blocker.log"
chmod 644 "$TARGET_DIR/logs/sustained_attacks.log"
chmod 644 "$TARGET_DIR/blocked_ips.db"

echo "   ✔ Data & log files created"
echo ""

# Step 6: Enable UFW
echo "6️⃣ Ensuring UFW Firewall is enabled..."

ufw --force enable > /dev/null 2>&1 && \
echo "   ✔ UFW enabled" || \
echo "   ⚠ UFW may already be enabled or unavailable"

echo ""

# Step 7: Initial backup
echo "7️⃣ Creating initial backup..."

INIT_BACKUP="$TARGET_DIR/backup/initial_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$INIT_BACKUP"
cp "$TARGET_DIR/"*.conf "$INIT_BACKUP/" 2>/dev/null

echo "   ✔ Initial backup stored at:"
echo "     $INIT_BACKUP"
echo ""

# Final summary
echo "================================="
echo "🎉 Enhanced IP Blocker Installed!"
echo "================================="
echo ""
echo "Features Installed:"
echo "   ✔ Basic IP blocking"
echo "   ✔ Global failure monitoring"
echo "   ✔ Username correlation detection"
echo "   ✔ Connection ratio analysis"
echo "   ✔ Extended time window detection"
echo "   ✔ Backup & log system"
echo "   ✔ Whitelist support"
echo ""
echo "🔧 Next Steps:"
echo "   1. Review configuration: $TARGET_DIR/config.conf"
echo "   2. Edit whitelist:       $TARGET_DIR/whitelist.conf"
echo "   3. Add cron job:"
echo "      */5 * * * * root $TARGET_DIR/ip_blocker.sh"
echo ""
echo "🛑 To uninstall:"
echo "      sudo $TARGET_DIR/uninstall.sh"
echo ""

