# Squid Proxy Setup and Troubleshooting Guide

This repository contains scripts for setting up a Squid SSL proxy with automatic certificate distribution and client configuration.

## Overview

The setup process consists of the following stages:

1. **Linux Server**: Install and configure Squid Proxy with SSL certificate generation
2. **Linux Server**: Start web server to share the SSL certificate
3. **Windows Client**: Download and install the SSL certificate
4. **Windows Client**: Configure proxy settings machine-wide
5. **Clean shutdown**: Squid closes connections after certificate download

## Directory Structure

```
├── Proxy/
│   ├── squid-ssl-setup.sh      # Main Squid installation and configuration
│   └── serve_certificate.sh    # Web server for certificate distribution
└── Windows/
    ├── download_certificate.ps1 # Download and install SSL certificate
    ├── set_proxy.ps1           # Configure machine-wide proxy settings
    └── block_firewall_aws.ps1  # Block AWS traffic (optional)
```

## Setup Process

### Linux Server Setup

**Step 1: Install Squid with SSL support**
```bash
sudo ./Proxy/squid-ssl-setup.sh
```

**Step 2: Start certificate web server**
```bash
sudo ./Proxy/serve_certificate.sh
```

### Windows Client Setup

**Step 1: Download and install certificate**
```powershell
.\Windows\download_certificate.ps1 -proxyHostname "10.0.0.7"
```

**Step 2: Configure proxy settings**
```powershell
.\Windows\set_proxy.ps1 -proxyHostname "10.0.0.7" -proxyPort 3128
```

## Troubleshooting Guide

### 1. Squid Service Issues

#### Check if Squid is Running

```bash
# Check service status
sudo systemctl status squid

# Check if ports are listening
sudo netstat -tlnp | grep squid
# or
sudo ss -tlnp | grep squid
```

**Expected Output:**
- Service should be `active (running)`
- Ports 3128 (standard) and 3129 (SSL bump) should be listening

#### Check Squid Logs

```bash
# Main log file (setup script)
sudo tail -f /opt/squid-ssl-setup.log

# Squid access logs
sudo tail -f /var/log/squid/access.log

# Squid error logs
sudo tail -f /var/log/squid/cache.log
```

#### Common Squid Issues

**Issue: Squid fails to start**
```bash
# Test configuration syntax
sudo squid -k parse

# Check for permission issues
sudo chown -R proxy:proxy /etc/squid/ssl_cert/
sudo chown -R proxy:proxy /var/lib/squid/

# Restart service
sudo systemctl restart squid
```

**Issue: SSL certificate database errors**
```bash
# Reinitialize SSL database
sudo rm -rf /var/lib/squid/ssl_db
sudo -u proxy /usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 4MB
```

### 2. Certificate Web Server Issues

#### Check Certificate Server Status

```bash
# Check if server is running
ps aux | grep "python3 -m http.server"

# Check server logs
tail -f /opt/serve_certificate.log

# Check if port 8080 is available
sudo netstat -tlnp | grep :8080
```

#### Manual Certificate Server Start

If the certificate server isn't running automatically:

```bash
cd /etc/squid/ssl_cert/
sudo python3 -m http.server 8080
```

#### Verify Certificate File

```bash
# Check if certificate exists
ls -la /etc/squid/ssl_cert/squid-ca-cert.pem

# Verify certificate content
openssl x509 -in /etc/squid/ssl_cert/squid-ca-cert.pem -text -noout
```

### 3. Windows Certificate Download Issues

#### Check Certificate Download Logs

```powershell
# View debug logs
Get-Content C:\Scripts\download_certificate_debug.log -Tail 50

# Check if certificate file was downloaded
Test-Path ".\squid-ca-cert.crt"
```

#### Manual Certificate Download

If automatic download fails:

```powershell
# Test connectivity to certificate server
Test-NetConnection -ComputerName "10.0.0.7" -Port 8080

# Download certificate manually
Invoke-WebRequest -Uri "http://10.0.0.7:8080/squid-ca-cert.pem" -OutFile "squid-ca-cert.pem"

# Convert to .crt format
Rename-Item "squid-ca-cert.pem" "squid-ca-cert.crt"
```

#### Verify Certificate Installation

```powershell
# Check if certificate is in trusted store
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*Squid CA*"}

# Check certificate details
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*Squid CA*"} | Format-List *
```

#### Manual Certificate Installation

```powershell
# Install certificate manually
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(".\squid-ca-cert.crt")
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$store.Open("ReadWrite")
$store.Add($cert)
$store.Close()
```

### 4. Windows Proxy Configuration Issues

#### Check Proxy Settings

```powershell
# Check registry settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"

# Check WinHTTP proxy settings
netsh winhttp show proxy
```

#### Manual Proxy Configuration

```powershell
# Configure registry manually
$proxyServer = "10.0.0.7:3128"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value $proxyServer

# Configure WinHTTP proxy
netsh winhttp set proxy $proxyServer
```

#### Reset Proxy Settings

```powershell
# Disable proxy
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0

# Reset WinHTTP
netsh winhttp reset proxy
```

### 5. Network Connectivity Issues

#### Test Basic Connectivity

```bash
# From Linux server - test if Windows can reach server
ping 10.0.0.7

# Check firewall rules (Linux)
sudo ufw status
sudo iptables -L
```

```powershell
# From Windows - test connectivity to Linux
Test-NetConnection -ComputerName "10.0.0.7" -Port 3128
Test-NetConnection -ComputerName "10.0.0.7" -Port 8080
```

#### Common Network Issues

**Issue: Connection refused**
- Check if Squid is running on the specified port
- Verify firewall rules allow traffic on ports 3128, 3129, and 8080
- Ensure correct IP address/hostname is being used

**Issue: Timeout errors**
- Check network routing between client and server
- Verify no intermediate firewalls are blocking traffic
- Increase timeout values in scripts if network is slow

### 6. Manual Execution Steps

If scripts don't run automatically, execute them manually in this order:

#### Linux Server

1. **Install Squid:**
   ```bash
   cd Proxy/
   chmod +x squid-ssl-setup.sh
   sudo ./squid-ssl-setup.sh
   ```

2. **Start Certificate Server:**
   ```bash
   chmod +x serve_certificate.sh
   sudo ./serve_certificate.sh
   ```

#### Windows Client

1. **Download Certificate:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\Windows\download_certificate.ps1 -proxyHostname "10.0.0.7"
   ```

2. **Configure Proxy:**
   ```powershell
   .\Windows\set_proxy.ps1 -proxyHostname "10.0.0.7" -proxyPort 3128
   ```

### 7. Debug Information Collection

When reporting issues, collect the following information:

#### Linux Server
```bash
# System information
uname -a
cat /etc/os-release

# Squid status and logs
sudo systemctl status squid
sudo tail -50 /opt/squid-ssl-setup.log
sudo tail -50 /var/log/squid/cache.log

# Network and ports
sudo netstat -tlnp | grep -E "(3128|3129|8080)"
```

#### Windows Client
```powershell
# System information
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory

# Certificate and proxy status
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*Squid*"}
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
netsh winhttp show proxy

# Script logs
Get-Content C:\Scripts\download_certificate_debug.log -Tail 20
Get-Content C:\Scripts\set_proxy_debug.log -Tail 20
```

## Script Locations and Log Files

### Linux Server
- **Scripts:** `./Proxy/`
- **Logs:**
  - `/opt/squid-ssl-setup.log` (Squid setup)
  - `/opt/serve_certificate.log` (Certificate server)
  - `/var/log/squid/` (Squid runtime logs)
- **Certificates:** `/etc/squid/ssl_cert/`

### Windows Client
- **Scripts:** `.\Windows\`
- **Logs:**
  - `C:\Scripts\download_certificate_debug.log`
  - `C:\Scripts\set_proxy_debug.log`
- **Certificates:** Installed in `Cert:\LocalMachine\Root`

## Security Notes

- The certificate server automatically shuts down after successful download
- Squid is configured to close connections after certificate distribution
- All scripts include comprehensive logging for audit purposes
- The setup creates a machine-wide proxy configuration affecting all users

## Support

For additional troubleshooting, check the detailed logs generated by each script. All scripts include debug output and error handling to help identify issues.