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

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Required command not found: $1"
        return 1
    fi
    log "✓ Command found: $1"
    return 0
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        error "Required file not found: $1"
        return 1
    fi
    log "✓ File exists: $1"
    return 0
}

# Function to check if a directory exists
check_dir() {
    if [ ! -d "$1" ]; then
        error "Required directory not found: $1"
        return 1
    fi
    log "✓ Directory exists: $1"
    return 0
}

# Function to check service status
check_service() {
    if ! systemctl is-active --quiet "$1"; then
        error "Service not running: $1"
        return 1
    fi
    log "✓ Service running: $1"
    return 0
}

# Check required commands
log "Checking required commands..."
check_command hostapd || exit 1
check_command dnsmasq || exit 1
check_command dhcpcd || exit 1
check_command python3 || exit 1
check_command pip3 || exit 1
check_command git || exit 1

# Check installation directory
log "Checking installation directory..."
check_dir "$INSTALL_DIR" || exit 1
check_dir "$INSTALL_DIR/venv" || exit 1

# Check service files
log "Checking service files..."
check_file "/etc/systemd/system/eink-bootstrap.service" || exit 1
check_file "/etc/systemd/system/eink.service" || exit 1

# Check service status
log "Checking service status..."
check_service "eink-bootstrap@$SERVICE_USER.service" || exit 1
check_service "eink@$SERVICE_USER.service" || exit 1

# Check WiFi configuration directory
log "Checking WiFi configuration..."
check_dir "/boot/eink" || exit 1
check_file "/boot/eink/README.md" || exit 1

# Check Python virtual environment
log "Checking Python virtual environment..."
if [ ! -f "$INSTALL_DIR/venv/bin/activate" ]; then
    error "Python virtual environment not properly set up"
    exit 1
fi
log "✓ Python virtual environment exists"

# Check if inky package is installed
log "Checking Python packages..."
if ! "$INSTALL_DIR/venv/bin/pip" list | grep -q "inky"; then
    error "inky package not installed"
    exit 1
fi
log "✓ inky package installed"

# Check network interface
log "Checking network interface..."
if ! ip link show wlan0 >/dev/null 2>&1; then
    error "wlan0 interface not found"
    exit 1
fi
log "✓ wlan0 interface exists"

# Check log file
log "Checking log file..."
if [ ! -f "/var/log/eink-bootstrap.log" ]; then
    warn "Log file not found: /var/log/eink-bootstrap.log"
else
    log "✓ Log file exists"
fi

# Check permissions
log "Checking permissions..."
if [ "$(stat -c '%U' "$INSTALL_DIR")" != "$SERVICE_USER" ]; then
    error "Installation directory owned by wrong user"
    exit 1
fi
log "✓ Installation directory permissions correct"

if [ "$(stat -c '%U' "/boot/eink")" != "$SERVICE_USER" ]; then
    error "WiFi configuration directory owned by wrong user"
    exit 1
fi
log "✓ WiFi configuration directory permissions correct"

log "Verification complete! All checks passed."
log "The installation appears to be working correctly." 