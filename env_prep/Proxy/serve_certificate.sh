#!/bin/bash
# serve_certificate.sh - Auto-serving certificate web server with logging

# Configuration
CERT_DIR="/etc/squid/ssl_cert"
CERT_FILE="squid-ca-cert.pem"
WEB_PORT="8080"
LOG_FILE="/opt/serve_certificate.log"
PID_FILE="/tmp/cert_server.pid"
EXEC_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Create log file
sudo mkdir -p /opt
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | sudo tee -a "$LOG_FILE"
    echo "$message"
}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Initialize log file
log_message "=========================================="
log_message "CERTIFICATE SERVER STARTUP"
log_message "Execution Time: $EXEC_TIME"
log_message "Script PID: $$"
log_message "User: $(whoami)"
log_message "=========================================="

echo -e "${GREEN}🌐 SQUID CERTIFICATE AUTO-SERVER${NC}"
echo -e "${GREEN}=================================${NC}"
echo -e "${BLUE}📝 Logging to: $LOG_FILE${NC}"
echo ""
echo -e "${BLUE}📁 Certificate Directory: ${CERT_DIR}${NC}"
echo -e "${BLUE}📄 Certificate File: ${CERT_FILE}${NC}"
echo -e "${BLUE}🌐 Web Server Port: ${WEB_PORT}${NC}"
echo -e "${BLUE}🖥️  Server IP: $(hostname -I | awk '{print $1}')${NC}"
echo ""

# Function to cleanup and exit
cleanup() {
    log_message "Cleanup initiated"
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            echo -e "${YELLOW}   Stopping web server (PID: $pid)...${NC}"
            log_message "Stopping web server PID: $pid"
            kill $pid 2>/dev/null
            sleep 2
            # Force kill if still running
            if ps -p $pid > /dev/null 2>&1; then
                kill -9 $pid 2>/dev/null
                log_message "Force killed web server PID: $pid"
            fi
        fi
        rm -f "$PID_FILE"
    fi
    rm -f "/tmp/cert_server.log"
    log_message "Cleanup completed"
    echo -e "${GREEN}✅ Cleanup completed.${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Validation checks
echo -e "${CYAN}🔍 Running pre-flight checks...${NC}"
log_message "Starting pre-flight checks"

# Check if certificate exists
if [ ! -f "$CERT_DIR/$CERT_FILE" ]; then
    echo -e "${RED}❌ Error: Certificate file not found: $CERT_DIR/$CERT_FILE${NC}"
    echo -e "${YELLOW}💡 Make sure you've run the Squid installation script first.${NC}"
    log_message "ERROR: Certificate file not found: $CERT_DIR/$CERT_FILE"
    exit 1
fi
echo -e "${GREEN}   ✅ Certificate file found${NC}"
log_message "Certificate file found: $CERT_DIR/$CERT_FILE"

# Check if port is already in use
if netstat -tuln 2>/dev/null | grep -q ":$WEB_PORT " || ss -tuln 2>/dev/null | grep -q ":$WEB_PORT "; then
    echo -e "${RED}❌ Error: Port $WEB_PORT is already in use${NC}"
    echo -e "${YELLOW}🔍 Checking what's using the port:${NC}"
    PORT_INFO=$(netstat -tulnp 2>/dev/null | grep ":$WEB_PORT " || ss -tulnp 2>/dev/null | grep ":$WEB_PORT ")
    echo "$PORT_INFO"
    log_message "ERROR: Port $WEB_PORT is already in use: $PORT_INFO"
    exit 1
fi
echo -e "${GREEN}   ✅ Port $WEB_PORT is available${NC}"
log_message "Port $WEB_PORT is available"

# Check if we can access the certificate directory
if ! cd "$CERT_DIR" 2>/dev/null; then
    echo -e "${RED}❌ Error: Cannot access certificate directory: $CERT_DIR${NC}"
    log_message "ERROR: Cannot access certificate directory: $CERT_DIR"
    exit 1
fi
echo -e "${GREEN}   ✅ Certificate directory accessible${NC}"
log_message "Certificate directory accessible"

echo ""

# Start the web server
echo -e "${YELLOW}🚀 Starting certificate web server...${NC}"
log_message "Starting certificate web server on port $WEB_PORT"
echo ""
echo -e "${CYAN}📡 Certificate will be served at:${NC}"
echo -e "${CYAN}   http://$(hostname -I | awk '{print $1}'):$WEB_PORT/$CERT_FILE${NC}"
echo ""
echo -e "${BLUE}⏱️  Server will auto-shutdown after successful certificate download.${NC}"
echo -e "${BLUE}🛑 Press Ctrl+C to stop manually${NC}"
echo ""

# Start Python web server in background and capture its output
python3 -m http.server $WEB_PORT > /tmp/cert_server.log 2>&1 &
SERVER_PID=$!
echo $SERVER_PID > "$PID_FILE"
log_message "Web server started with PID: $SERVER_PID"

# Check if server started successfully
sleep 2
if ! ps -p $SERVER_PID > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Failed to start web server${NC}"
    echo -e "${YELLOW}📋 Error details:${NC}"
    ERROR_DETAILS=$(cat /tmp/cert_server.log 2>/dev/null)
    echo "$ERROR_DETAILS"
    log_message "ERROR: Failed to start web server: $ERROR_DETAILS"
    cleanup
fi

echo -e "${GREEN}✅ Web server started successfully (PID: $SERVER_PID)${NC}"
echo -e "${CYAN}👀 Monitoring for certificate downloads...${NC}"
echo ""
log_message "Web server running successfully, monitoring downloads"

# Monitor the log file for successful downloads
tail -f /tmp/cert_server.log 2>/dev/null | while read line; do
    echo "$line"
    log_message "HTTP: $line"
    
    # Check for successful GET request for the certificate
    if echo "$line" | grep -q "GET /$CERT_FILE.*HTTP.*200"; then
        client_ip=$(echo "$line" | awk '{print $1}')
        timestamp=$(echo "$line" | grep -oP '\[.*?\]')
        
        echo ""
        echo -e "${GREEN}🎉 Certificate successfully downloaded!${NC}"
        echo -e "${CYAN}   📍 Client IP: $client_ip${NC}"
        echo -e "${CYAN}   ⏰ Time: $timestamp${NC}"
        echo -e "${YELLOW}   🛑 Auto-stopping web server in 3 seconds...${NC}"
        
        log_message "SUCCESS: Certificate downloaded by $client_ip at $timestamp"
        log_message "Auto-stopping web server in 3 seconds"
        
        # Wait a moment to ensure download completed, then cleanup
        sleep 3
        log_message "Certificate server session completed successfully"
        kill $$ 2>/dev/null  # Kill the main script to trigger cleanup
        break
    fi
    
    # Also show HEAD requests (used by download scripts for checking)
    if echo "$line" | grep -q "HEAD /$CERT_FILE.*HTTP.*200"; then
        client_ip=$(echo "$line" | awk '{print $1}')
        echo -e "${BLUE}   📋 Certificate check from $client_ip${NC}"
        log_message "Certificate check from $client_ip"
    fi
done
