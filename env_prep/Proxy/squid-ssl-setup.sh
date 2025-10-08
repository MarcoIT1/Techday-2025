#!/bin/bash

# =============================================================================
# Squid SSL Proxy Setup Script with Logging
# Complete automated installation with all working steps
# =============================================================================

# Logging configuration
LOG_FILE="/opt/squid-ssl-setup.log"
EXEC_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Create log file and add header
sudo mkdir -p /opt
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | sudo tee -a "$LOG_FILE"
}

# Function to print and log status messages
print_step() {
    local step_msg="📋 STEP $1: $2"
    echo "$step_msg"
    echo "$(printf '%.0s-' {1..50})"
    log_message "STEP $1: $2"
}

print_status() {
    local msg="[INFO] $1"
    echo "$msg"
    log_message "INFO: $1"
}

print_success() {
    local msg="[SUCCESS] $1"
    echo "$msg"
    log_message "SUCCESS: $1"
}

print_error() {
    local msg="[ERROR] $1"
    echo "$msg"
    log_message "ERROR: $1"
}

# Initialize log file
log_message "=========================================="
log_message "SQUID SSL PROXY SETUP STARTED"
log_message "Execution Time: $EXEC_TIME"
log_message "Script PID: $$"
log_message "User: $(whoami)"
log_message "System: $(uname -a)"
log_message "=========================================="

echo "🚀 SQUID SSL PROXY SETUP"
echo "========================"
echo "📝 Logging to: $LOG_FILE"
echo ""

# Add error handling
handle_error() {
    log_message "FATAL ERROR: Script failed at line $1"
    log_message "Last command exit code: $2"
    print_error "Script failed! Check log file: $LOG_FILE"
    
    # Capture system state
    log_message "=== SYSTEM STATE AT ERROR ==="
    sudo systemctl status squid --no-pager 2>&1 | sudo tee -a "$LOG_FILE"
    log_message "=== END SYSTEM STATE ==="
    
    log_message "SCRIPT EXECUTION FAILED"
    exit 1
}

trap 'handle_error $LINENO $?' ERR

# =============================================================================
# STEP 0: Install squid-openssl
# =============================================================================
print_step "0" "Installing squid-openssl"
log_message "Starting package installation..."

print_status "Updating package list..."
if sudo apt update 2>&1 | sudo tee -a "$LOG_FILE"; then
    log_message "Package list updated successfully"
else
    handle_error $LINENO $?
fi

print_status "Installing squid-openssl (includes SSL certificate generation tools)..."
if sudo apt install squid-openssl -y 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "squid-openssl installed successfully"
    
    # Get version info
    SQUID_VERSION=$(squid -v | head -1 | grep -o 'Version [0-9.]*' | cut -d' ' -f2)
    print_success "Squid installed successfully (Version: $SQUID_VERSION)"
    log_message "Squid version: $SQUID_VERSION"
    
    # Enable service
    print_status "Enabling Squid service..."
    if sudo systemctl enable squid 2>&1 | sudo tee -a "$LOG_FILE"; then
        print_success "Squid service is enabled"
    else
        handle_error $LINENO $?
    fi
else
    print_error "Failed to install squid-openssl"
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 1: Create SSL certificate directory
# =============================================================================
print_step "1" "Creating SSL certificate directory"
print_status "Creating SSL certificate directory..."
if sudo mkdir -p /etc/squid/ssl_cert 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "SSL certificate directory created"
else
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 2: Create the CA private key
# =============================================================================
print_step "2" "Creating CA private key"
print_status "Generating CA private key (4096 bits)..."
if sudo openssl genrsa -out /etc/squid/ssl_cert/squid-ca-key.pem 4096 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "CA private key generated"
else
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 3: Create the CA certificate
# =============================================================================
print_step "3" "Creating CA certificate"
print_status "Generating CA certificate..."
if sudo openssl req -new -x509 -days 3650 \
    -key /etc/squid/ssl_cert/squid-ca-key.pem \
    -out /etc/squid/ssl_cert/squid-ca-cert.pem \
    -utf8 -subj "/C=IE/ST=Cork/L=Cork/O=TM/OU=TS/CN=Squid CA" 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "CA certificate generated"
else
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 4: Set proper permissions
# =============================================================================
print_step "4" "Setting proper permissions"
print_status "Setting proper permissions..."
if sudo chown -R proxy:proxy /etc/squid/ssl_cert/ 2>&1 | sudo tee -a "$LOG_FILE" && \
   sudo chmod 400 /etc/squid/ssl_cert/squid-ca-key.pem 2>&1 | sudo tee -a "$LOG_FILE" && \
   sudo chmod 444 /etc/squid/ssl_cert/squid-ca-cert.pem 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "Permissions set correctly"
else
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 5: Initialize SSL certificate database
# =============================================================================
print_step "5" "Initializing SSL certificate database"

print_status "Creating SSL certificate database parent directory..."
if sudo mkdir -p /var/lib/squid 2>&1 | sudo tee -a "$LOG_FILE" && \
   sudo chown -R proxy:proxy /var/lib/squid 2>&1 | sudo tee -a "$LOG_FILE"; then
    log_message "SSL database directory created"
else
    handle_error $LINENO $?
fi

print_status "Initializing SSL certificate database..."
if sudo -u proxy /usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 4MB 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "SSL certificate database initialized successfully"
else
    print_error "Failed to initialize as proxy user, trying as root..."
    log_message "Retrying SSL database initialization as root..."
    
    if sudo /usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 4MB 2>&1 | sudo tee -a "$LOG_FILE"; then
        print_status "Setting database ownership..."
        if sudo chown -R proxy:proxy /var/lib/squid/ssl_db 2>&1 | sudo tee -a "$LOG_FILE" && \
           sudo chmod -R 755 /var/lib/squid/ssl_db 2>&1 | sudo tee -a "$LOG_FILE"; then
            print_success "SSL certificate database initialized successfully"
        else
            handle_error $LINENO $?
        fi
    else
        print_error "Failed to initialize SSL certificate database"
        handle_error $LINENO $?
    fi
fi

print_status "Verifying SSL database..."
if [ -d "/var/lib/squid/ssl_db" ] && [ "$(ls -A /var/lib/squid/ssl_db 2>/dev/null)" ]; then
    print_success "SSL database created and populated"
    echo "Database contents:"
    ls -la /var/lib/squid/ssl_db/ | head -3 | sudo tee -a "$LOG_FILE"
else
    print_error "SSL database verification failed"
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 6: Backup original configuration
# =============================================================================
print_step "6" "Backing up original configuration"
if [ ! -f /etc/squid/squid.conf.original ]; then
    print_status "Backing up original squid configuration..."
    if sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.original 2>&1 | sudo tee -a "$LOG_FILE"; then
        print_success "Configuration backed up to /etc/squid/squid.conf.original"
    else
        handle_error $LINENO $?
    fi
else
    print_success "Configuration backup already exists"
fi

echo ""

# =============================================================================
# STEP 7: Add SSL bump configuration
# =============================================================================
print_step "7" "Adding SSL bump configuration"
print_status "Adding SSL bump configuration to squid.conf..."
if sudo tee -a /etc/squid/squid.conf << 'EOF' 2>&1 | sudo tee -a "$LOG_FILE"

# SSL Bump Configuration
http_port 3129 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=4MB cert=/etc/squid/ssl_cert/squid-ca-cert.pem key=/etc/squid/ssl_cert/squid-ca-key.pem

# ACL for SSL bumping
acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3

# SSL bump rules
ssl_bump peek step1
ssl_bump bump step2
ssl_bump bump step3

# Cache directory for SSL certificates
sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/lib/squid/ssl_db -M 4MB
sslcrtd_children 5
EOF
then
    print_success "SSL bump configuration added"
else
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 7.5: Configure network access
# =============================================================================
print_step "7.5" "Configuring network access"
print_status "Adding localnet access rule to allow network clients..."
if sudo sed -i '/http_access allow localhost$/a http_access allow localnet' /etc/squid/squid.conf 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "Network access configured - clients can now connect"
    
    # Verify the rule was added
    print_status "Verifying access rules..."
    if grep -q "http_access allow localnet" /etc/squid/squid.conf; then
        print_success "Localnet access rule confirmed in configuration"
    else
        print_error "Localnet access rule not found in configuration"
        handle_error $LINENO $?
    fi
else
    print_error "Failed to add localnet access rule"
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 8: Test configuration
# =============================================================================

print_step "8" "Testing configuration"
print_status "Validating squid configuration..."
if sudo squid -k parse 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "Configuration is valid"
else
    print_error "Configuration validation failed!"
    print_status "Configuration errors:"
    sudo squid -k parse 2>&1 | sudo tee -a "$LOG_FILE"
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 9: Restart squid
# =============================================================================
print_step "9" "Restarting Squid service"
print_status "Restarting squid service..."
if sudo systemctl restart squid 2>&1 | sudo tee -a "$LOG_FILE"; then
    print_success "Squid service restarted successfully"
    
    # Wait a moment for squid to fully start
    sleep 3
else
    print_error "Failed to restart squid service"
    handle_error $LINENO $?
fi

echo ""

# =============================================================================
# STEP 10: Verify status
# =============================================================================
print_step "10" "Verifying installation"
print_status "Checking squid service status..."
if sudo systemctl is-active --quiet squid; then
    print_success "Squid service is running"
    
    # Show listening ports
    print_status "Squid is listening on the following ports:"
    sudo netstat -tlnp 2>/dev/null | grep squid 2>&1 | sudo tee -a "$LOG_FILE" || sudo ss -tlnp | grep squid 2>&1 | sudo tee -a "$LOG_FILE"
    
    echo ""
    echo "🎉 INSTALLATION COMPLETED SUCCESSFULLY!"
    echo "======================================"
    echo ""
    echo "📊 Configuration Summary:"
    echo "   Regular HTTP Proxy: http://localhost:3128"
    echo "   SSL Bump Proxy:     http://localhost:3129"
    echo "   CA Certificate:     /etc/squid/ssl_cert/squid-ca-cert.pem"
    
else
    print_error "Squid service is not running!"
    print_status "Service status:"
    sudo systemctl status squid --no-pager 2>&1 | sudo tee -a "$LOG_FILE"
    handle_error $LINENO $?
fi

echo ""

echo "✅ Setup completed successfully!"
echo "📝 Check log file for details: $LOG_FILE"
