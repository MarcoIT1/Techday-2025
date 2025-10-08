# Certificate Download and Installation Script with Dynamic IP Detection
param(
    [string]$ProxyName = "TD-Proxy",
    [int]$MaxRetries = 30,
    [int]$RetryDelay = 10
)

# Setup logging
$logDir = "C:\Scripts\Logs"
$logFile = Join-Path $logDir "download_certificate.log"

# Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $Message  # Changed from Write-Output to Write-Host
}

Write-Log "Certificate Download and Installation" "INFO"
Write-Log "Log file: $logFile" "INFO"
Write-Log "Searching for proxy server: $ProxyName" "INFO"

# Function to resolve hostname to IP
function Get-ProxyIP {
    param([string]$Hostname)
    
    Write-Log "Attempting DNS resolution for: $Hostname" "DEBUG"
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

# Resolve proxy IP address
$ProxyIP = Get-ProxyIP -Hostname $ProxyName

if (-not $ProxyIP) {
    Write-Log "ERROR: Cannot resolve hostname '$ProxyName'" "ERROR"
    Write-Log "Please ensure:" "ERROR"
    Write-Log "  1. The proxy server is running" "ERROR"
    Write-Log "  2. DNS resolution is working" "ERROR"
    Write-Log "  3. Network connectivity is available" "ERROR"
    exit 1
}

Write-Log "Resolved $ProxyName to IP: $ProxyIP" "SUCCESS"

# Certificate download URL
$CertificateURL = "http://${ProxyIP}:8080/squid-ca-cert.pem"
Write-Log "Certificate URL: $CertificateURL" "INFO"
Write-Log "Max Retries: $MaxRetries" "INFO"
Write-Log "Retry Delay: $RetryDelay seconds" "INFO"

# Test connection function
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
            Write-Log "TCP connection to ${IP}:${Port} successful" "DEBUG"
            return $true
        } else {
            $tcpClient.Close()
            Write-Log "TCP connection to ${IP}:${Port} timed out" "DEBUG"
            return $false
        }
    }
    catch {
        Write-Log "TCP connection to ${IP}:${Port} failed: $($_.Exception.Message)" "DEBUG"
        return $false
    }
}

# Test HTTP response function
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
        Write-Log "HTTP request failed: $($_.Exception.Message)" "DEBUG"
        return $false
    }
}

# Step 1: Wait for proxy server to be accessible
Write-Log "Step 1: Checking Proxy Server Accessibility..." "INFO"
$Connected = $false
$Attempt = 1

while (-not $Connected -and $Attempt -le $MaxRetries) {
    Write-Log "Attempt $Attempt/$MaxRetries - Testing connection to ${ProxyIP}:8080..." "INFO"
    
    if (Test-ProxyConnection -IP $ProxyIP -Port 8080) {
        Write-Log "TCP connection successful!" "SUCCESS"
        Write-Log "Testing HTTP response..." "INFO"
        
        if (Test-HTTPResponse -URL $CertificateURL) {
            Write-Log "Web server is accessible and responding!" "SUCCESS"
            $Connected = $true
        } else {
            Write-Log "TCP connects but HTTP server not ready" "WARN"
        }
    } else {
        Write-Log "Cannot connect to ${ProxyIP}:8080" "WARN"
    }
    
    if (-not $Connected) {
        if ($Attempt -lt $MaxRetries) {
            Write-Log "Waiting $RetryDelay seconds before retry..." "INFO"
            Start-Sleep -Seconds $RetryDelay
        }
        $Attempt++
    }
}

if (-not $Connected) {
    Write-Log "ERROR: Cannot connect to proxy server after $MaxRetries attempts" "ERROR"
    Write-Log "Please ensure the certificate server is running on ${ProxyIP}:8080" "ERROR"
    exit 1
}

# Step 2: Download the certificate
Write-Log "Step 2: Downloading Certificate..." "INFO"
$TempPath = [System.IO.Path]::GetTempPath()
$CertPath = Join-Path $TempPath "squid-ca-cert.pem"
Write-Log "Temporary certificate path: $CertPath" "DEBUG"

try {
    Write-Log "Downloading from: $CertificateURL" "INFO"
    Invoke-WebRequest -Uri $CertificateURL -OutFile $CertPath -UseBasicParsing
    
    if (Test-Path $CertPath) {
        $FileSize = (Get-Item $CertPath).Length
        Write-Log "Certificate downloaded successfully!" "SUCCESS"
        Write-Log "Downloaded certificate size: $FileSize bytes" "INFO"
        
        # Basic validation
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
    Write-Log "ERROR: Failed to download certificate" "ERROR"
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Step 3: Rename certificate to .crt extension
Write-Log "Step 3: Renaming Certificate..." "INFO"
$CrtPath = $CertPath -replace "\.pem$", ".crt"

try {
    Rename-Item -Path $CertPath -NewName (Split-Path $CrtPath -Leaf)
    Write-Log "Certificate renamed: $(Split-Path $CertPath -Leaf) to $(Split-Path $CrtPath -Leaf)" "SUCCESS"
    Write-Log "Final location: $CrtPath" "INFO"
}
catch {
    Write-Log "ERROR: Failed to rename certificate" "ERROR"
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Step 4: Install the certificate
Write-Log "Step 4: Installing Certificate..." "INFO"
try {
    Write-Log "Installing to: Trusted Root Certification Authorities (Local Machine)" "INFO"
    
    # Import certificate to Local Machine Trusted Root store
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CrtPath)
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    
    Write-Log "Certificate installed successfully!" "SUCCESS"
    Write-Log "Certificate Thumbprint: $($cert.Thumbprint)" "INFO"
    Write-Log "Certificate Subject: $($cert.Subject)" "INFO"
    Write-Log "Certificate Valid Until: $($cert.NotAfter)" "INFO"
}
catch {
    Write-Log "ERROR: Failed to install certificate" "ERROR"
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    Write-Log "Note: This script must be run as Administrator to install certificates" "ERROR"
    exit 1
}

# Step 5: Cleanup and verification
Write-Log "Step 5: Cleanup and Verification..." "INFO"
try {
    Remove-Item $CrtPath -Force
    Write-Log "Temporary certificate file cleaned up" "SUCCESS"
}
catch {
    Write-Log "WARNING: Could not clean up temporary file: $CrtPath" "WARN"
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
    Write-Log "WARNING: Could not verify certificate installation: $($_.Exception.Message)" "WARN"
}

Write-Log "Certificate Installation Complete!" "SUCCESS"
Write-Log "Summary:" "INFO"
Write-Log "  Server accessibility: VERIFIED" "INFO"
Write-Log "  Certificate download: SUCCESS" "INFO"
Write-Log "  Certificate rename: SUCCESS" "INFO"
Write-Log "  Certificate import: SUCCESS" "INFO"
Write-Log "  Cleanup: COMPLETED" "INFO"
Write-Log "Certificate Details:" "INFO"
Write-Log "  Subject: $($cert.Subject)" "INFO"
Write-Log "  Thumbprint: $($cert.Thumbprint)" "INFO"
Write-Log "  Valid Until: $($cert.NotAfter)" "INFO"
Write-Log "Certificate is ready for proxy usage." "SUCCESS"
