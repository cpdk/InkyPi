#!/bin/bash

# Exit on error
set -e

# Configuration
INSTALL_DIR="${1:-$HOME/eink}"  # Use provided directory or default to ~/eink
SERVICE_USER="$SUDO_USER"  # Use the user who ran sudo

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

# Stop services
log "Stopping services..."
systemctl stop eink-bootstrap@$SERVICE_USER.service || true
systemctl stop eink@$SERVICE_USER.service || true

# Disable services
log "Disabling services..."
systemctl disable eink-bootstrap@$SERVICE_USER.service || true
systemctl disable eink@$SERVICE_USER.service || true

# Remove service files
log "Removing service files..."
rm -f /etc/systemd/system/eink-bootstrap.service
rm -f /etc/systemd/system/eink.service

# Reload systemd
systemctl daemon-reload

# Remove WiFi configuration
log "Removing WiFi configuration..."
rm -f /boot/eink/wifi.yml
rm -f /boot/eink/README.md
rmdir /boot/eink 2>/dev/null || true

# Remove installation directory
log "Removing installation directory..."
rm -rf "$INSTALL_DIR"

# Remove log files
log "Removing log files..."
rm -f /var/log/eink-bootstrap.log

# Remove Python virtual environment
log "Removing Python virtual environment..."
rm -rf "$INSTALL_DIR/venv"

# Note: We don't remove the installed packages (hostapd, dnsmasq, etc.)
# as they might be used by other services

log "Uninstallation complete!"
log "Note: The following packages were not removed as they might be used by other services:"
log "- hostapd"
log "- dnsmasq"
log "- dhcpcd5"
log "- python3-pip"
log "- python3-pil"
log "- python3-venv"
log "- python3-full"
log "- git"
log "- wget"
log "- curl"
log ""
log "If you want to remove these packages, please do so manually with:"
log "apt-get remove hostapd dnsmasq dhcpcd5 python3-pip python3-pil python3-venv python3-full git wget curl" 