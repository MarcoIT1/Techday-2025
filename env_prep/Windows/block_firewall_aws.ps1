# Trend Micro Installation Download Blocker
Write-Host "=== Trend Micro Installation Download Blocker ===" -ForegroundColor Red
Write-Host "Simulating installation package download issues..." -ForegroundColor Yellow

function Add-ToHostsFile {
    param([string[]]$Domains, [string]$Description)
    
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    
    Write-Host "`nBlocking $Description..." -ForegroundColor Yellow
    
    foreach ($domain in $Domains) {
        $entry = "127.0.0.1 $domain"
        Add-Content -Path $hostsFile -Value $entry -Force
        Write-Host "  BLOCKED: $domain" -ForegroundColor Red
    }
}

# Block primary download servers
$DownloadServers = @(
    "download.trendmicro.com",
    "downloads.trendmicro.com", 
    "installer.trendmicro.com",
    "packages.trendmicro.com",
    "repository.trendmicro.com",
    "iuds.trendmicro.com"
)

Add-ToHostsFile -Domains $DownloadServers -Description "Primary Download Servers"

# Block regional download servers
$RegionalServers = @(
    "download-eu.trendmicro.com",
    "download-us.trendmicro.com", 
    "download-ap.trendmicro.com",
    "download-jp.trendmicro.com"
)

Add-ToHostsFile -Domains $RegionalServers -Description "Regional Download Servers"

# Block XBC/XDR API endpoints
$XBCServers = @(
    "api-eu1.xbc.trendmicro.com",
    "api-us1.xbc.trendmicro.com",
    "api-ap1.xbc.trendmicro.com",
    "api-jp1.xbc.trendmicro.com"
)

Add-ToHostsFile -Domains $XBCServers -Description "XBC/XDR API Endpoints"

# Block CDN endpoints (these are critical for downloads)
$CDNServers = @(
    "d2kqk8p6si7wva.cloudfront.net",
    "d1wqzb5bdbcre6.cloudfront.net", 
    "d3p8zr0ffa9t17.cloudfront.net",
    "cdn.trendmicro.com",
    "assets.trendmicro.com"
)

Add-ToHostsFile -Domains $CDNServers -Description "CDN/CloudFront Endpoints"

# Block update servers (also used during installation)
$UpdateServers = @(
    "update.trendmicro.com",
    "updates.trendmicro.com",
    "iuserver.trendmicro.com",
    "activeupdate.trendmicro.com"
)

Add-ToHostsFile -Domains $UpdateServers -Description "Update Servers"

# Flush DNS cache
Write-Host "`nFlushing DNS cache..." -ForegroundColor Yellow
ipconfig /flushdns | Out-Null
Write-Host "DNS cache flushed" -ForegroundColor Green

Write-Host "`n============================================================"
Write-Host "INSTALLATION DOWNLOAD BLOCKING ACTIVE" -ForegroundColor Red
Write-Host "============================================================"
Write-Host "BLOCKED SERVICES:" -ForegroundColor Red
Write-Host "- Primary download servers" -ForegroundColor Red
Write-Host "- Regional download mirrors" -ForegroundColor Red  
Write-Host "- XBC/XDR API endpoints" -ForegroundColor Red
Write-Host "- CDN/CloudFront distributions" -ForegroundColor Red
Write-Host "- Update servers" -ForegroundColor Red
Write-Host ""
Write-Host "PRESERVED SERVICES:" -ForegroundColor Green
Write-Host "- Portal access (signin.v1.trendmicro.com)" -ForegroundColor Green
Write-Host "- Console access (portal.xdr.trendmicro.com)" -ForegroundColor Green
Write-Host ""
Write-Host "EXPECTED INSTALLATION ISSUES:" -ForegroundColor Yellow
Write-Host "- Installation will fail to download packages" -ForegroundColor Yellow
Write-Host "- Installer may show download timeout errors" -ForegroundColor Yellow  
Write-Host "- Agent deployment will fail" -ForegroundColor Yellow
Write-Host "- Update processes will fail" -ForegroundColor Yellow
Write-Host ""
Write-Host "PORTAL ACCESS SHOULD STILL WORK:" -ForegroundColor Cyan
Write-Host "https://signin.v1.trendmicro.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "To restore downloads, run the cleanup script" -ForegroundColor White

# Test that portal is still accessible
Write-Host "`nTesting portal access..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://signin.v1.trendmicro.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Host "SUCCESS: Portal is still accessible (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Portal test failed - $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`nInstallation download blocking is now ACTIVE!" -ForegroundColor Red
Write-Host "Try installing a Trend Micro agent to test the blocking." -ForegroundColor White
