#!/bin/bash

# Error handling function
error() {
    echo "Error: $1" >&2
    exit 1
}

# Check if user argument is provided
if [ -z "$1" ]; then
    error "User argument is required"
fi

REAL_USER="$1"

# Validate user exists
if ! id "$REAL_USER" &>/dev/null; then
    error "User '$REAL_USER' does not exist"
fi

# Validate user has a home directory
if [ ! -d "/home/$REAL_USER" ]; then
    error "User '$REAL_USER' has no home directory"
fi

# Validate user has a shell
USER_SHELL=$(getent passwd "$REAL_USER" | cut -d: -f7)
if [ ! -x "$USER_SHELL" ]; then
    error "User '$REAL_USER' has no valid shell"
fi

# Debug information
echo "Debug: Script started"
echo "Debug: Current user: $(whoami)"
echo "Debug: HOME: $HOME"
echo "Debug: USER: $USER"
echo "Debug: REAL_USER: $REAL_USER"
echo "Debug: User home: /home/$REAL_USER"
echo "Debug: User shell: $USER_SHELL"
echo "Debug: Current directory: $(pwd)"
echo "Debug: Script location: $0"
echo "Debug: Script directory: $(dirname "$0")"

# Configuration
LOG_FILE="/var/log/eink-bootstrap.log"
DISPLAY_SCRIPT="$HOME/eink/bootstrap/display-hotspot.py"
VENV_PYTHON="$HOME/eink/venv/bin/python"
WIFI_CONFIG="/boot/eink/wifi.yml"
INSTALL_DIR="$HOME/eink"

# Debug information
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Ensure proper permissions
ensure_permissions() {
    log "Setting up permissions..."
    chown -R "$REAL_USER:$REAL_USER" "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    chmod 644 "$LOG_FILE"
}

# Check if we have internet connectivity
check_internet() {
    log "Checking internet connectivity..."
    ping -c 1 8.8.8.8 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Internet connection detected"
        return 0
    else
        log "No internet connection detected"
        return 1
    fi
}

# Configure WiFi from yml file
configure_wifi() {
    log "Configuring WiFi from $WIFI_CONFIG..."
    
    # Check if yml file exists
    if [ ! -f "$WIFI_CONFIG" ]; then
        log "No WiFi configuration file found"
        return 1
    fi
    
    # Install yq if not present
    if ! command -v yq &> /dev/null; then
        log "Installing yq..."
        wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64
        chmod +x /usr/local/bin/yq
    fi
    
    # Read networks from yml file
    networks=$(yq e '.networks[]' "$WIFI_CONFIG")
    
    # Configure each network
    while IFS= read -r network; do
        ssid=$(echo "$network" | yq e '.ssid' -)
        password=$(echo "$network" | yq e '.password' -)
        priority=$(echo "$network" | yq e '.priority' -)
        
        log "Configuring network: $ssid (priority: $priority)"
        
        # Add network to wpa_supplicant.conf
        cat >> /etc/wpa_supplicant/wpa_supplicant.conf << EOF
network={
    ssid="$ssid"
    psk="$password"
    priority=$priority
}
EOF
    done <<< "$networks"
    
    # Restart networking
    systemctl restart wpa_supplicant
    systemctl restart dhcpcd
    
    # Wait for connection
    log "Waiting for WiFi connection..."
    for i in {1..30}; do
        if check_internet; then
            log "Successfully connected to WiFi"
            # Remove config file
            rm "$WIFI_CONFIG"
            return 0
        fi
        sleep 2
    done
    
    log "Failed to connect to WiFi"
    return 1
}

# Configure hotspot
setup_hotspot() {
    log "Setting up WiFi hotspot..."
    
    # Generate random 5-digit number for hotspot name
    HOTSPOT_NAME="eink-hotspot-$(shuf -i 10000-99999 -n 1)"
    HOTSPOT_PASSWORD="eink-configure"
    
    # Configure hostapd
    cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$HOTSPOT_NAME
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$HOTSPOT_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

    # Configure dnsmasq
    cat > /etc/dnsmasq.conf << EOF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

    # Configure network interfaces
    cat > /etc/dhcpcd.conf << EOF
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

    # Start services
    systemctl unmask hostapd
    systemctl enable hostapd
    systemctl enable dnsmasq
    systemctl enable dhcpcd
    
    systemctl restart hostapd
    systemctl restart dnsmasq
    systemctl restart dhcpcd
    
    # Display hotspot information
    if [ -f "$DISPLAY_SCRIPT" ]; then
        log "Displaying hotspot information..."
        sudo -u "$REAL_USER" "$VENV_PYTHON" "$DISPLAY_SCRIPT" "$HOTSPOT_NAME" "$HOTSPOT_PASSWORD" "192.168.4.1"
    fi
    
    log "Hotspot setup complete. SSID: $HOTSPOT_NAME, Password: $HOTSPOT_PASSWORD"
}

# Update application
update_application() {
    log "Updating application..."
    cd "$INSTALL_DIR"
    sudo -u "$REAL_USER" git pull --depth 1
    systemctl restart eink@$REAL_USER.service
}

# Main execution
log "Starting e-ink bootstrapper"

# Ensure proper permissions
ensure_permissions

# Check for WiFi configuration file
if [ -f "$WIFI_CONFIG" ]; then
    log "Found WiFi configuration file"
    if configure_wifi; then
        log "Successfully configured WiFi"
        update_application
        exit 0
    else
        log "Failed to configure WiFi"
    fi
fi

# Check internet connectivity
if check_internet; then
    log "Internet connection detected"
    update_application
    exit 0
fi

# No internet connection, set up hotspot
log "No internet connection, setting up hotspot"
setup_hotspot

log "Bootstrapper completed" 