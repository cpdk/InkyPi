#!/bin/bash

# Exit on error
set -e

# Configuration
REPO_URL="https://github.com/yourusername/eink-bootstrapper.git"
INSTALL_DIR="${1:-$HOME/eink}"  # Use provided directory or default to ~/eink
VENV_DIR="$INSTALL_DIR/venv"
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

# Install required packages
log "Installing required packages..."
apt-get update
apt-get install -y \
    hostapd \
    dnsmasq \
    dhcpcd5 \
    python3-pip \
    python3-pil \
    python3-venv \
    python3-full \
    git \
    wget \
    curl

# Create installation directory
log "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

# Clone repository if not already present
if [ ! -d "$INSTALL_DIR/.git" ]; then
    log "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
fi

# Set up Python virtual environment
log "Setting up Python virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install inky[rpi]
    deactivate
fi

# Copy service files
log "Installing systemd services..."
cp "$INSTALL_DIR/bootstrap/eink-bootstrap.service" /etc/systemd/system/
cp "$INSTALL_DIR/bootstrap/eink.service" /etc/systemd/system/

# Update service files with correct paths
sed -i "s|/opt/eink|$INSTALL_DIR|g" /etc/systemd/system/eink-bootstrap.service
sed -i "s|/opt/eink|$INSTALL_DIR|g" /etc/systemd/system/eink.service

# Reload systemd
systemctl daemon-reload

# Enable and start services
log "Enabling and starting services..."
systemctl enable eink-bootstrap@$SERVICE_USER.service
systemctl enable eink@$SERVICE_USER.service

# Set up WiFi configuration directory
log "Setting up WiFi configuration..."
mkdir -p /boot/eink
chown -R "$SERVICE_USER:$SERVICE_USER" /boot/eink

# Create README for WiFi configuration
cat > /boot/eink/README.md << 'EOF'
# E-ink WiFi Configuration

To configure WiFi on this device:

1. Copy the template file from the repository:
```bash
cp ~/eink/bootstrap/wifi.yml.template /boot/eink/wifi.yml
```

2. Edit the wifi.yml file with your network details:
```yaml
networks:
  - ssid: "Your WiFi Name"
    password: "Your WiFi Password"
    priority: 1  # Higher numbers = higher priority
```

3. Save the file and reboot the device.

The device will:
1. Read this configuration file
2. Configure WiFi using the provided credentials
3. Delete this file after successful configuration
4. Start the main application if internet connection is established

If no internet connection is established:
1. The device will create a WiFi hotspot
2. The e-ink display will show connection instructions
3. You can connect to the hotspot and configure WiFi through the web interface

For more information, see the template file at ~/eink/bootstrap/wifi.yml.template
EOF

# Set permissions
chown -R "$SERVICE_USER:$SERVICE_USER" /boot/eink/README.md

# Start services
log "Starting services..."
systemctl start eink-bootstrap@$SERVICE_USER.service
systemctl start eink@$SERVICE_USER.service

log "Installation complete!"
log "The system will now:"
log "1. Check for internet connectivity on boot"
log "2. Look for wifi.yml in /boot/eink/ for WiFi configuration"
log "3. Create a hotspot if no internet is available"
log "4. Start the main application when internet is available"
log ""
log "You can check the service status with:"
log "systemctl status eink-bootstrap@$SERVICE_USER.service"
log "systemctl status eink@$SERVICE_USER.service" 