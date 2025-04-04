#!/bin/bash

# Exit on error
set -e

# Configuration
INSTALL_DIR="/opt/eink"
WIFI_CONFIG="/boot/eink/wifi.yml"
HOTSPOT_SSID="InkyPi"
HOTSPOT_PASSWORD="inkypi123"
LOG_FILE="/var/log/eink-bootstrap.log"
UPDATE_INTERVAL=3600  # Check for updates every hour
MAX_RETRIES=3
RETRY_DELAY=10

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    local exit_code=$1
    local line_no=$2
    log "Error occurred in line $line_no with exit code $exit_code"
    log "Stack trace:"
    caller | while read line; do
        log "  $line"
    done
    return $exit_code
}

# Set up error handling
trap 'handle_error $? $LINENO' ERR

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "Please run as root"
    exit 1
fi

# Function to check internet connectivity
check_internet() {
    log "Checking internet connectivity..."
    # Add timeout to ping command
    if timeout 5 ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Function to update application
update_application() {
    log "Checking for application updates..."
    cd "$INSTALL_DIR"
    
    # Since we're copying files directly, we'll just check if the virtual environment exists
    if [ ! -d "$INSTALL_DIR/venv" ]; then
        log "Setting up Python virtual environment..."
        python3 -m venv "$INSTALL_DIR/venv"
        source "$INSTALL_DIR/venv/bin/activate"
        if ! timeout 300 pip install -r requirements.txt; then
            log "Pip install timed out"
            return 1
        fi
        deactivate
        return 0
    fi
    
    log "No updates needed"
    return 0
}

# Function to configure WiFi from yml file
configure_wifi() {
    log "Configuring WiFi..."
    if [ ! -f "$WIFI_CONFIG" ]; then
        log "No WiFi configuration found"
        return 1
    fi

    # Read WiFi configuration
    while IFS= read -r line; do
        if [[ $line =~ ssid:[[:space:]]*\"([^\"]+)\" ]]; then
            SSID="${BASH_REMATCH[1]}"
        elif [[ $line =~ password:[[:space:]]*\"([^\"]+)\" ]]; then
            PASSWORD="${BASH_REMATCH[1]}"
        fi
    done < "$WIFI_CONFIG"

    if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
        log "Invalid WiFi configuration"
        return 1
    fi

    # Configure WiFi
    cat > /etc/wpa_supplicant/wpa_supplicant.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$SSID"
    psk="$PASSWORD"
    key_mgmt=WPA-PSK
}
EOF

    # Restart networking with retries
    for i in $(seq 1 $MAX_RETRIES); do
        log "Attempting to restart networking (attempt $i/$MAX_RETRIES)"
        systemctl restart wpa_supplicant
        systemctl restart dhcpcd
        sleep $RETRY_DELAY
        
        if iwgetid -r >/dev/null 2>&1; then
            log "WiFi configured successfully"
            rm "$WIFI_CONFIG"
            return 0
        fi
    done

    log "Failed to connect to WiFi after $MAX_RETRIES attempts"
    return 1
}

# Function to set up hotspot
setup_hotspot() {
    log "Setting up WiFi hotspot..."
    
    # Configure hostapd
    cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$HOTSPOT_SSID
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

    # Configure dhcpcd
    cat > /etc/dhcpcd.conf << EOF
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

    # Restart services with retries
    for i in $(seq 1 $MAX_RETRIES); do
        log "Attempting to start hotspot services (attempt $i/$MAX_RETRIES)"
        systemctl restart hostapd
        systemctl restart dnsmasq
        systemctl restart dhcpcd
        sleep $RETRY_DELAY
        
        if iwgetid -r >/dev/null 2>&1; then
            log "Hotspot started successfully"
            # Update display with configuration options
            "$INSTALL_DIR/venv/bin/python3" "$INSTALL_DIR/bootstrap/display-hotspot.py" "$HOTSPOT_SSID" "$HOTSPOT_PASSWORD" "192.168.4.1"
            return 0
        fi
    done
    
    log "Failed to start hotspot after $MAX_RETRIES attempts"
    return 1
}

# Function to show configuration display
show_config_display() {
    log "Showing configuration display..."
    "$INSTALL_DIR/venv/bin/python3" "$INSTALL_DIR/bootstrap/display-hotspot.py" "$HOTSPOT_SSID" "$HOTSPOT_PASSWORD" "192.168.4.1"
}

# Function to verify system health
verify_system() {
    log "Verifying system health..."
    
    # Check critical services with timeout
    local services=("hostapd" "dnsmasq" "dhcpcd" "wpa_supplicant")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            log "Service $service is not running, attempting to restart..."
            if ! timeout 10 systemctl restart "$service"; then
                log "Service $service restart timed out"
                continue
            fi
            sleep 5
            if ! systemctl is-active --quiet "$service"; then
                log "Failed to start $service"
                return 1
            fi
        fi
    done
    
    # Check disk space
    local disk_space=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_space" -gt 90 ]; then
        log "Warning: Disk space is low ($disk_space%)"
    fi
    
    # Check memory
    local memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    if (( $(echo "$memory_usage > 90" | bc -l) )); then
        log "Warning: Memory usage is high ($memory_usage%)"
    fi
    
    return 0
}

# Main bootstrap process
log "Starting bootstrap process..."

# Check if this is a manual configuration request
if [ "$1" = "configure" ]; then
    log "Manual configuration requested"
    show_config_display
    exit 0
fi

# Verify system health with timeout
if ! timeout 60 verify_system; then
    log "System health check failed or timed out"
    show_config_display
    exit 1
fi

# Check for internet connectivity
if check_internet; then
    log "Internet connection detected"
    
    # Check for updates with timeout
    if timeout 300 update_application; then
        log "Application updated successfully"
    else
        log "Application update timed out or failed"
    fi
    
    # Start the application
    if ! timeout 10 systemctl start eink.service; then
        log "Failed to start eink service"
        show_config_display
        exit 1
    fi
    exit 0
fi

# Try to configure WiFi if configuration exists
if configure_wifi; then
    log "WiFi configured successfully"
    if ! timeout 10 systemctl start eink.service; then
        log "Failed to start eink service"
        show_config_display
        exit 1
    fi
    exit 0
fi

# No internet and no WiFi config, set up hotspot
log "Setting up WiFi hotspot..."
if setup_hotspot; then
    log "Hotspot setup complete"
else
    log "Failed to set up hotspot"
    show_config_display
    exit 1
fi

exit 0 