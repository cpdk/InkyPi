#!/bin/bash

# Exit on error
set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "Please run as root (use sudo)"
    exit 1
fi

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
log "Repository directory: $REPO_DIR"

# Create symlink to /opt/eink
log "Creating symlink to /opt/eink..."
rm -f /opt/eink
ln -s "$REPO_DIR" /opt/eink

# Set up Python virtual environment
log "Setting up Python virtual environment..."
python3 -m venv /opt/eink/venv
source /opt/eink/venv/bin/activate
pip install -r /opt/eink/requirements.txt

# Install systemd services
log "Installing systemd services..."
cp /opt/eink/bootstrap/eink-bootstrap.service /etc/systemd/system/
cp /opt/eink/bootstrap/eink.service /etc/systemd/system/

# Reload systemd
log "Reloading systemd..."
systemctl daemon-reload

# Enable and start services
log "Enabling and starting services..."
systemctl enable eink-bootstrap.service
systemctl enable eink.service
systemctl start eink-bootstrap.service

# Create WiFi configuration directory
log "Setting up WiFi configuration..."
mkdir -p /boot/eink
cp /opt/eink/bootstrap/wifi.yml.template /boot/eink/wifi.yml

log "Installation complete!"
log "Please edit /boot/eink/wifi.yml with your WiFi credentials" 