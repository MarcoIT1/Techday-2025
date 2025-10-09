# Certificate Download and Installation Script with Dynamic IP Detection and Enhanced Debug Logging
param(
    [string]$ProxyName = "10.0.0.7",
    [int]$MaxRetries = 30,
    [int]$RetryDelay = 10
)

# Setup logging
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = if ($ScriptPath) { $ScriptPath } else { "C:\Scripts\Logs" }
$logFile = Join-Path $logDir "download_certificate_debug.log"

# Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Enhanced logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch { }
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
        default { Write-Host $logEntry -ForegroundColor White }
    }
}

# Clear previous log
if (Test-Path $logFile) {
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
}

Write-Log "========================================" "INFO"
Write-Log "Certificate Download & Install Script" "INFO"
Write-Log "========================================" "INFO"
Write-Log "Script started with parameters:" "INFO"
Write-Log "  ProxyName: $ProxyName" "INFO"
Write-Log "  MaxRetries: $MaxRetries" "INFO"
Write-Log "  RetryDelay: $RetryDelay" "INFO"
Write-Log "  Log file: $logFile" "INFO"

# Function to resolve hostname to IP
function Get-ProxyIP {
    param([string]$Hostname)
    
    Write-Log "=== DNS Resolution Phase ===" "DEBUG"
    
    # Check if input is already an IP address
    $ipPattern = '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    if ($Hostname -match $ipPattern) {
        Write-Log "Input is already an IP address: $Hostname" "SUCCESS"
        return $Hostname
    }
    
    Write-Log "Attempting DNS resolution for hostname: $Hostname" "DEBUG"
    try {
        $IPAddress = [System.Net.Dns]::GetHostAddresses($Hostname) | 
                    Where-Object { $_.AddressFamily -eq 'InterNetwork' } | 
                    Select-Object -First 1
        
        if ($IPAddress) {
            $resolvedIP = $IPAddress.IPAddressToString
            Write-Log "DNS resolution successful: $Hostname -> $resolvedIP" "SUCCESS"
            return $resolvedIP
        }
    }
    catch {
        Write-Log "DNS resolution failed for $Hostname : $($_.Exception.Message)" "ERROR"
    }
    return $null
}

# Test TCP connection
function Test-ProxyConnection {
    param([string]$IP, [int]$Port)
    
    Write-Log "Testing TCP connection to ${IP}:${Port}" "DEBUG"
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($IP, $Port, $null, $null)
        $waitHandle = $asyncResult.AsyncWaitHandle
        
        if ($waitHandle.WaitOne(5000)) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Close()
            Write-Log "TCP connection successful" "SUCCESS"
            return $true
        } else {
            $tcpClient.Close()
            Write-Log "TCP connection timed out" "WARN"
            return $false
        }
    }
    catch {
        Write-Log "TCP connection failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Test HTTP response
function Test-HTTPResponse {
    param([string]$URL)
    
    Write-Log "Testing HTTP response from: $URL" "DEBUG"
    try {
        $response = Invoke-WebRequest -Uri $URL -Method Head -TimeoutSec 10 -UseBasicParsing
        $success = $response.StatusCode -eq 200
        Write-Log "HTTP response: $($response.StatusCode) - Success: $success" "DEBUG"
        return $success
    }
    catch {
        Write-Log "HTTP request failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution
Write-Log "=== STEP 1: Resolving Proxy Address ===" "INFO"
$ProxyIP = Get-ProxyIP -Hostname $ProxyName

if (-not $ProxyIP) {
    Write-Log "FATAL: Cannot resolve hostname '$ProxyName'" "ERROR"
    exit 1
}

$CertificateURL = "http://${ProxyIP}:8080/squid-ca-cert.pem"
Write-Log "Certificate URL: $CertificateURL" "INFO"

Write-Log "=== STEP 2: Testing Connectivity ===" "INFO"
$Connected = $false
$Attempt = 1

while (-not $Connected -and $Attempt -le $MaxRetries) {
    Write-Log "Attempt $Attempt of $MaxRetries" "INFO"
    
    if (Test-ProxyConnection -IP $ProxyIP -Port 8080) {
        if (Test-HTTPResponse -URL $CertificateURL) {
            Write-Log "Proxy server is accessible!" "SUCCESS"
            $Connected = $true
        } else {
            Write-Log "TCP connects but HTTP not ready" "WARN"
        }
    } else {
        Write-Log "Cannot connect to ${ProxyIP}:8080" "WARN"
    }
    
    if (-not $Connected) {
        if ($Attempt -lt $MaxRetries) {
            Write-Log "Waiting $RetryDelay seconds..." "INFO"
            Start-Sleep -Seconds $RetryDelay
        }
        $Attempt++
    }
}

if (-not $Connected) {
    Write-Log "FATAL: Cannot connect after $MaxRetries attempts" "ERROR"
    exit 1
}

Write-Log "=== STEP 3: Downloading Certificate ===" "INFO"
$TempPath = [System.IO.Path]::GetTempPath()
$CertPath = Join-Path $TempPath "squid-ca-cert.pem"

try {
    Write-Log "Downloading from: $CertificateURL" "INFO"
    Invoke-WebRequest -Uri $CertificateURL -OutFile $CertPath -UseBasicParsing
    
    if (Test-Path $CertPath) {
        $FileSize = (Get-Item $CertPath).Length
        Write-Log "Certificate downloaded! Size: $FileSize bytes" "SUCCESS"
        
        # Validate certificate format
        $Content = Get-Content $CertPath -Raw
        if ($Content -match "BEGIN CERTIFICATE" -and $Content -match "END CERTIFICATE") {
            Write-Log "Certificate format validation passed!" "SUCCESS"
        } else {
            throw "Invalid certificate format"
        }
    } else {
        throw "Certificate file not found after download"
    }
}
catch {
    Write-Log "ERROR: Failed to download certificate: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "=== STEP 4: Renaming Certificate ===" "INFO"
$CrtPath = $CertPath -replace "\.pem$", ".crt"

try {
    Rename-Item -Path $CertPath -NewName (Split-Path $CrtPath -Leaf)
    Write-Log "Certificate renamed to: $(Split-Path $CrtPath -Leaf)" "SUCCESS"
}
catch {
    Write-Log "ERROR: Failed to rename certificate: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "=== STEP 5: Installing Certificate ===" "INFO"
try {
    Write-Log "Installing to Trusted Root Certification Authorities..." "INFO"
    
    # Import certificate
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CrtPath)
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    
    Write-Log "Certificate installed successfully!" "SUCCESS"
    Write-Log "Certificate Subject: $($cert.Subject)" "INFO"
    Write-Log "Certificate Thumbprint: $($cert.Thumbprint)" "INFO"
    Write-Log "Certificate Valid Until: $($cert.NotAfter)" "INFO"
}
catch {
    Write-Log "ERROR: Failed to install certificate: $($_.Exception.Message)" "ERROR"
    Write-Log "Note: This script must be run as Administrator" "ERROR"
    exit 1
}

Write-Log "=== STEP 6: Cleanup and Verification ===" "INFO"
try {
    Remove-Item $CrtPath -Force
    Write-Log "Temporary certificate file cleaned up" "SUCCESS"
}
catch {
    Write-Log "WARNING: Could not clean up temporary file" "WARN"
}

# Verify installation
try {
    $installedCerts = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Subject -like "*Squid CA*" }
    if ($installedCerts.Count -gt 0) {
        Write-Log "Certificate verified in Windows certificate store!" "SUCCESS"
        Write-Log "Found $($installedCerts.Count) Squid certificate(s)" "INFO"
    } else {
        Write-Log "WARNING: Certificate not found in store after installation" "WARN"
    }
}
catch {
    Write-Log "WARNING: Could not verify certificate installation" "WARN"
}

Write-Log "========================================" "SUCCESS"
Write-Log "CERTIFICATE INSTALLATION COMPLETE!" "SUCCESS"
Write-Log "========================================" "SUCCESS"
Write-Log "Summary:" "INFO"
Write-Log "  ✅ Server accessibility: VERIFIED" "INFO"
Write-Log "  ✅ Certificate download: SUCCESS" "INFO"
Write-Log "  ✅ Certificate installation: SUCCESS" "INFO"
Write-Log "  ✅ Cleanup: COMPLETED" "INFO"
Write-Log "Certificate is ready for proxy usage!" "SUCCESS"
