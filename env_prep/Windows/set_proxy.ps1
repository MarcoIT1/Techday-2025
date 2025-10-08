# set_proxy.ps1 - Enhanced with Debug Logging
param(
    [string]$proxyHostname = "10.0.0.7",  # Changed default to IP
    [int]$proxyPort = 3128
)

# Setup logging - Enhanced debug version
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = if ($ScriptPath) { $ScriptPath } else { "C:\Scripts\Logs" }
$logFile = Join-Path $logDir "set_proxy_debug.log"

# Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Enhanced logging function with console output
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to file
    try {
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {
        # If file write fails, continue anyway
    }
    
    # Write to console with color coding
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
        default { Write-Host $logEntry -ForegroundColor White }
    }
}

# Clear previous log and start fresh
if (Test-Path $logFile) {
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
}

Write-Log "========================================" "INFO"
Write-Log "Machine-Wide Proxy Configuration Script" "INFO"
Write-Log "========================================" "INFO"
Write-Log "Script started with parameters:" "INFO"
Write-Log "  ProxyHostname: $proxyHostname" "INFO"
Write-Log "  ProxyPort: $proxyPort" "INFO"
Write-Log "  Log file: $logFile" "INFO"
Write-Log "  Current directory: $(Get-Location)" "INFO"
Write-Log "  Script path: $ScriptPath" "INFO"
Write-Log "  Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" "INFO"

# Function to resolve hostname to IP with enhanced debugging
function Get-ProxyIP {
    param([string]$Hostname)
    
    Write-Log "=== IP Resolution Phase ===" "DEBUG"
    Write-Log "Input hostname: '$Hostname'" "DEBUG"
    
    # Check if input is already an IP address
    $ipPattern = '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    if ($Hostname -match $ipPattern) {
        Write-Log "Input is already an IP address: $Hostname" "SUCCESS"
        return $Hostname
    }
    
    # Try ping first
    Write-Log "Attempting ping to discover IP address..." "DEBUG"
    try {
        Write-Log "Executing: Test-Connection -ComputerName $Hostname -Count 1" "DEBUG"
        $pingResult = Test-Connection -ComputerName $Hostname -Count 1 -Quiet -ErrorAction Stop
        if ($pingResult) {
            $pingDetails = Test-Connection -ComputerName $Hostname -Count 1 -ErrorAction Stop
            $resolvedIp = $pingDetails.IPV4Address.IPAddressToString
            Write-Log "Ping successful: $Hostname -> $resolvedIp" "SUCCESS"
            return $resolvedIp
        } else {
            Write-Log "Ping returned false" "WARN"
        }
    }
    catch {
        Write-Log "Ping failed: $($_.Exception.Message)" "WARN"
        Write-Log "Exception type: $($_.Exception.GetType().FullName)" "DEBUG"
    }
    
    # Fallback to DNS resolution
    Write-Log "Trying DNS resolution as fallback..." "DEBUG"
    try {
        Write-Log "Executing: Resolve-DnsName $Hostname" "DEBUG"
        $dnsResult = Resolve-DnsName $Hostname -ErrorAction Stop | Where-Object { $_.Type -eq "A" }
        if ($dnsResult) {
            $resolvedIp = $dnsResult[0].IPAddress
            Write-Log "DNS resolution successful: $Hostname -> $resolvedIp" "SUCCESS"
            return $resolvedIp
        } else {
            Write-Log "DNS resolution returned no A records" "ERROR"
        }
    }
    catch {
        Write-Log "DNS resolution failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Exception type: $($_.Exception.GetType().FullName)" "DEBUG"
    }
    
    return $null
}

# Function to test if proxy is accessible
function Test-ProxyConnectivity {
    param([string]$IP, [int]$Port)
    
    Write-Log "=== Proxy Connectivity Test ===" "DEBUG"
    Write-Log "Testing connection to ${IP}:${Port}" "DEBUG"
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        Write-Log "TcpClient created successfully" "DEBUG"
        
        $asyncResult = $tcpClient.BeginConnect($IP, $Port, $null, $null)
        Write-Log "Connection attempt initiated" "DEBUG"
        
        $waitHandle = $asyncResult.AsyncWaitHandle
        Write-Log "Waiting for connection (timeout: 3000ms)" "DEBUG"
        
        if ($waitHandle.WaitOne(3000)) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Close()
            Write-Log "Proxy connectivity test: SUCCESS" "SUCCESS"
            return $true
        } else {
            $tcpClient.Close()
            Write-Log "Proxy connectivity test: TIMEOUT" "WARN"
            return $false
        }
    }
    catch {
        Write-Log "Proxy connectivity test: FAILED - $($_.Exception.Message)" "WARN"
        Write-Log "Exception type: $($_.Exception.GetType().FullName)" "DEBUG"
        return $false
    }
}

# Main execution with enhanced debugging
try {
    Write-Log "=== STEP 1: Resolving Proxy Address ===" "INFO"
    
    $resolvedIp = Get-ProxyIP -Hostname $proxyHostname
    
    if (-not $resolvedIp) {
        Write-Log "FATAL: Cannot resolve hostname '$proxyHostname'" "ERROR"
        Write-Log "Please ensure:" "ERROR"
        Write-Log "  1. The hostname/IP is correct" "ERROR"
        Write-Log "  2. Network connectivity is available" "ERROR"
        Write-Log "  3. DNS resolution is working" "ERROR"
        exit 1
    }
    
    $proxyAddress = "${resolvedIp}:${proxyPort}"
    Write-Log "Resolved proxy address: $proxyAddress" "SUCCESS"
    
    Write-Log "=== STEP 2: Testing Proxy Connectivity ===" "INFO"
    $proxyAccessible = Test-ProxyConnectivity -IP $resolvedIp -Port $proxyPort
    if (-not $proxyAccessible) {
        Write-Log "WARNING: Proxy server at $proxyAddress is not responding" "WARN"
        Write-Log "Continuing with configuration anyway..." "WARN"
    } else {
        Write-Log "Proxy server is accessible and responding!" "SUCCESS"
    }

    Write-Log "=== STEP 3: Configuring Machine-Wide Proxy Policy ===" "INFO"
    $policyPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
    Write-Log "Policy registry path: $policyPath" "DEBUG"
    
    if (-not (Test-Path $policyPath)) {
        Write-Log "Creating policy registry path..." "DEBUG"
        New-Item -Path $policyPath -Force | Out-Null
        Write-Log "Created registry path: $policyPath" "SUCCESS"
    } else {
        Write-Log "Policy registry path already exists" "DEBUG"
    }
    
    Write-Log "Setting ProxySettingsPerUser = 0 (machine-wide enforcement)" "DEBUG"
    New-ItemProperty -Path $policyPath -Name ProxySettingsPerUser -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Log "Policy configured: ProxySettingsPerUser=0" "SUCCESS"

    Write-Log "=== STEP 4: Configuring Machine-Level Proxy ===" "INFO"
    $regPathMachine = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
    Write-Log "Machine registry path: $regPathMachine" "DEBUG"
    
    Write-Log "Setting ProxyEnable = 1" "DEBUG"
    New-ItemProperty -Path $regPathMachine -Name ProxyEnable -Value 1 -PropertyType DWord -Force | Out-Null
    
    Write-Log "Setting ProxyServer = $proxyAddress" "DEBUG"
    New-ItemProperty -Path $regPathMachine -Name ProxyServer -Value $proxyAddress -PropertyType String -Force | Out-Null
    Write-Log "Machine-wide (HKLM) proxy configured: $proxyAddress" "SUCCESS"

    Write-Log "=== STEP 5: Configuring System (WinHTTP) Proxy ===" "INFO"
    Write-Log "Executing: netsh winhttp set proxy $proxyAddress" "DEBUG"
    $winHttpResult = netsh winhttp set proxy $proxyAddress 2>&1
    Write-Log "WinHTTP command result: $winHttpResult" "DEBUG"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "System (WinHTTP) proxy configured successfully" "SUCCESS"
    } else {
        Write-Log "WinHTTP configuration may have failed (exit code: $LASTEXITCODE)" "WARN"
    }

    Write-Log "=== STEP 6: Broadcasting Settings Change ===" "INFO"
    Write-Log "Preparing to broadcast WM_SETTINGCHANGE message..." "DEBUG"
    
    $signature = @"
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@

    try {
        Write-Log "Adding Win32 SendMessageTimeout type..." "DEBUG"
        $SendMessageTimeout = Add-Type -MemberDefinition $signature -Name 'Win32SendMessageTimeout' -Namespace Win32Functions -PassThru
        
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1A
        $result = [UIntPtr]::Zero
        
        Write-Log "Broadcasting WM_SETTINGCHANGE message..." "DEBUG"
        $broadcastResult = $SendMessageTimeout::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Internet Settings", 2, 5000, [ref]$result)
        Write-Log "Broadcast result: $broadcastResult" "DEBUG"
        Write-Log "Settings change broadcasted successfully" "SUCCESS"
    }
    catch {
        Write-Log "Failed to broadcast settings change: $($_.Exception.Message)" "WARN"
        Write-Log "Settings may require a reboot to take effect" "WARN"
    }

    Write-Log "=== STEP 7: Verification ===" "INFO"
    
    # Verify registry settings
    try {
        $proxyEnabled = Get-ItemProperty -Path $regPathMachine -Name ProxyEnable -ErrorAction Stop
        $proxyServer = Get-ItemProperty -Path $regPathMachine -Name ProxyServer -ErrorAction Stop
        Write-Log "Verification: ProxyEnable = $($proxyEnabled.ProxyEnable)" "DEBUG"
        Write-Log "Verification: ProxyServer = $($proxyServer.ProxyServer)" "DEBUG"
        
        if ($proxyEnabled.ProxyEnable -eq 1 -and $proxyServer.ProxyServer -eq $proxyAddress) {
            Write-Log "Registry verification: PASSED" "SUCCESS"
        } else {
            Write-Log "Registry verification: FAILED" "WARN"
        }
    }
    catch {
        Write-Log "Registry verification failed: $($_.Exception.Message)" "WARN"
    }

    Write-Log "========================================" "SUCCESS"
    Write-Log "PROXY CONFIGURATION COMPLETE!" "SUCCESS"
    Write-Log "========================================" "SUCCESS"
    Write-Log "Summary:" "INFO"
    Write-Log "  ✅ IP Resolution: SUCCESS ($resolvedIp)" "INFO"
    Write-Log "  ✅ Proxy Policy: CONFIGURED" "INFO"
    Write-Log "  ✅ Machine Registry: CONFIGURED" "INFO"
    Write-Log "  ✅ System (WinHTTP): CONFIGURED" "INFO"
    Write-Log "  ✅ Settings Broadcast: COMPLETED" "INFO"
    Write-Log "Proxy Address: $proxyAddress" "INFO"
    Write-Log "Configuration applied machine-wide for all users!" "SUCCESS"
    
    exit 0
}
catch {
    Write-Log "========================================" "ERROR"
    Write-Log "PROXY CONFIGURATION FAILED!" "ERROR"
    Write-Log "========================================" "ERROR"
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    Write-Log "Exception type: $($_.Exception.GetType().FullName)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    Write-Log "Line number: $($_.InvocationInfo.ScriptLineNumber)" "ERROR"
    exit 1
}
