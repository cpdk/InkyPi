#!/bin/bash

# Exit on error
set -e

# Configuration
INSTALL_DIR="${1:-$HOME/eink}"  # Use provided directory or default to ~/eink
SERVICE_USER="$SUDO_USER"  # Use the user who ran sudo
TEST_DURATION=300  # 5 minutes in seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
    exit 1
fi

# Check if SUDO_USER is set
if [ -z "$SUDO_USER" ]; then
    error "Please run with sudo"
    exit 1
fi

# Function to backup network configuration
backup_network_config() {
    log "Backing up network configuration..."
    cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
    cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.backup 2>/dev/null || true
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true
}

# Function to restore network configuration
restore_network_config() {
    log "Restoring network configuration..."
    cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
    cp /etc/hostapd/hostapd.conf.backup /etc/hostapd/hostapd.conf 2>/dev/null || true
    cp /etc/dnsmasq.conf.backup /etc/dnsmasq.conf 2>/dev/null || true
    systemctl restart dhcpcd
    systemctl restart hostapd
    systemctl restart dnsmasq
}

# Function to check if wlan0 is in AP mode
check_ap_mode() {
    if iwconfig wlan0 | grep -q "Mode:Master"; then
        return 0
    fi
    return 1
}

# Function to get hotspot details
get_hotspot_details() {
    SSID=$(grep "^ssid=" /etc/hostapd/hostapd.conf | cut -d= -f2)
    PASSWORD=$(grep "^wpa_passphrase=" /etc/hostapd/hostapd.conf | cut -d= -f2)
    IP=$(grep "^static ip_address=" /etc/dhcpcd.conf | cut -d= -f2 | cut -d/ -f1)
    echo "$SSID|$PASSWORD|$IP"
}

# Backup current configuration
backup_network_config

# Stop existing services
log "Stopping existing services..."
systemctl stop eink-bootstrap@$SERVICE_USER.service || true
systemctl stop eink@$SERVICE_USER.service || true
systemctl stop hostapd || true
systemctl stop dnsmasq || true

# Configure hotspot
log "Configuring hotspot..."
"$INSTALL_DIR/bootstrap/bootstrap.sh"

# Wait for hotspot to start
log "Waiting for hotspot to start..."
for i in {1..30}; do
    if check_ap_mode; then
        break
    fi
    sleep 1
done

if ! check_ap_mode; then
    error "Failed to start hotspot"
    restore_network_config
    exit 1
fi

# Get hotspot details
IFS='|' read -r SSID PASSWORD IP <<< "$(get_hotspot_details)"
log "Hotspot started successfully!"
log "SSID: $SSID"
log "Password: $PASSWORD"
log "IP Address: $IP"
log ""
log "You can now:"
log "1. Connect to the hotspot with these credentials"
log "2. Test the connection by pinging $IP"
log "3. The hotspot will automatically stop after $TEST_DURATION seconds"
log ""
log "To stop the test early, press Ctrl+C"

# Wait for test duration
sleep "$TEST_DURATION"

# Restore configuration
log "Test complete, restoring network configuration..."
restore_network_config

# Restart services
log "Restarting services..."
systemctl start eink-bootstrap@$SERVICE_USER.service || true
systemctl start eink@$SERVICE_USER.service || true

log "Test complete! Network configuration has been restored." 