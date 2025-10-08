# set_proxy.ps1
param(
    [string]$proxyHostname = "td-proxy",
    [int]$proxyPort = 3129
)

# Setup logging
$logDir = "C:\Scripts\Logs"
$logFile = Join-Path $logDir "set_proxy.log"

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
    Write-Output $Message
}

Write-Log "Starting machine-wide proxy configuration..." "INFO"
Write-Log "Log file: $logFile" "INFO"

try {
    # Dynamically discover td-proxy IP via ping
    Write-Log "Discovering IP address for hostname: $proxyHostname" "INFO"
    
    try {
        # Try ping to get actual IP
        Write-Log "Attempting ping to $proxyHostname..." "DEBUG"
        $pingResult = Test-Connection -ComputerName $proxyHostname -Count 1 -Quiet -ErrorAction Stop
        if ($pingResult) {
            $resolvedIp = (Test-Connection -ComputerName $proxyHostname -Count 1).IPV4Address.IPAddressToString
            $proxyAddress = "${resolvedIp}:${proxyPort}"
            Write-Log "Ping successful: $proxyHostname -> $resolvedIp" "SUCCESS"
            Write-Log "Using proxy: $proxyAddress" "INFO"
        } else {
            throw "Ping failed"
        }
    }
    catch {
        # Fallback to DNS resolution
        Write-Log "Ping failed: $($_.Exception.Message)" "WARN"
        Write-Log "Trying DNS resolution..." "INFO"
        try {
            $dnsResult = Resolve-DnsName $proxyHostname -ErrorAction Stop | Where-Object { $_.Type -eq "A" }
            if ($dnsResult) {
                $resolvedIp = $dnsResult[0].IPAddress
                $proxyAddress = "${resolvedIp}:${proxyPort}"
                Write-Log "DNS resolved: $proxyHostname -> $resolvedIp" "SUCCESS"
                Write-Log "Using proxy: $proxyAddress" "INFO"
            } else {
                throw "DNS resolution failed"
            }
        }
        catch {
            Write-Log "Cannot resolve $proxyHostname. Check network connectivity." "ERROR"
            Write-Log "Error details: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }

    # Force machine-wide proxy (disable per-user proxy)
    Write-Log "Configuring machine-wide proxy policy..." "INFO"
    $policyPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
    if (-not (Test-Path $policyPath)) {
        New-Item -Path $policyPath -Force | Out-Null
        Write-Log "Created registry path: $policyPath" "DEBUG"
    }
    New-ItemProperty -Path $policyPath -Name ProxySettingsPerUser -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Log "Policy: ProxySettingsPerUser=0 (machine-wide proxy enforced)" "SUCCESS"

    # Configure proxy at machine level (HKLM)
    Write-Log "Setting machine-level proxy configuration..." "INFO"
    $regPathMachine = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
    New-ItemProperty -Path $regPathMachine -Name ProxyEnable -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPathMachine -Name ProxyServer -Value $proxyAddress -PropertyType String -Force | Out-Null
    Write-Log "Machine-wide (HKLM) proxy set to $proxyAddress" "SUCCESS"

    # Configure system proxy (WinHTTP)
    Write-Log "Configuring system (WinHTTP) proxy..." "INFO"
    $winHttpResult = netsh winhttp set proxy $proxyAddress 2>&1
    Write-Log "WinHTTP result: $winHttpResult" "DEBUG"
    Write-Log "System (WinHTTP) proxy set to $proxyAddress" "SUCCESS"

    # Force refresh so changes apply immediately
    Write-Log "Broadcasting settings change..." "INFO"
    $signature = @"
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@

    $SendMessageTimeout = Add-Type -MemberDefinition $signature -Name 'Win32SendMessageTimeout' -Namespace Win32Functions -PassThru

    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x1A
    $result = [UIntPtr]::Zero

    $SendMessageTimeout::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Internet Settings", 2, 5000, [ref]$result) | Out-Null
    Write-Log "Broadcasted WM_SETTINGCHANGE -> Internet Settings refreshed" "SUCCESS"

    Write-Log "Proxy successfully configured globally: $proxyAddress" "SUCCESS"
    Write-Log "Configuration completed successfully" "INFO"
    exit 0
}
catch {
    Write-Log "Failed to configure proxy: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
