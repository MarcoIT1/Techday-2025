# Deploy Policy from Prepared_Policy to Windows Server
# Reads API key and region from Api_Configuration.json

Write-Host "=== Trend Micro Cloud One - Deploy Policy ===" -ForegroundColor Cyan

# Load configuration
$configPath = Join-Path $PSScriptRoot "Api_Configuration.json"
if (!(Test-Path $configPath)) {
    Write-Host "Api_Configuration.json not found. Please run API_Collection.ps1 first." -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath | ConvertFrom-Json
$region = $config.Region
$apiKey = $config.ApiKey
$baseUrl = $config.BaseUrl

# Helper: Invoke API
function Invoke-CloudOneApi {
    param (
        [string]$Method,
        [string]$Url,
        [object]$Body = $null
    )
    $headers = @{
        'api-secret-key' = $apiKey
        'api-version'    = 'v1'
        'Content-Type'   = 'application/json'
        'Accept'         = 'application/json'
    }
    if ($Body) {
        $jsonBody = $Body | ConvertTo-Json -Depth 10
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -Body $jsonBody
    } else {
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
    }
}

# Find policy by name
function Get-PolicyIdByName {
    param([string]$Name)
    $policies = Invoke-CloudOneApi GET "$baseUrl/policies"
    foreach ($p in $policies.policies) {
        if ($p.name -eq $Name) { return $p.ID }
    }
    Write-Host "Policy '$Name' not found." -ForegroundColor Red
    exit 1
}

# Find policy by path
function Get-PolicyIdByPath {
    param([string[]]$Path)
    $policies = Invoke-CloudOneApi GET "$baseUrl/policies"
    $current = $null
    foreach ($name in $Path) {
        $found = $null
        foreach ($p in $policies.policies) {
            if ($p.name -eq $name -and ($null -eq $current -or $p.parentID -eq $current.ID)) {
                $found = $p
                break
            }
        }
        if ($null -eq $found) {
            Write-Host "Policy path not found: $($Path -join ' -> ')" -ForegroundColor Red
            exit 1
        }
        $current = $found
    }
    return $current.ID
}

# Get full policy details
function Get-PolicyDetails {
    param([int]$Id)
    return Invoke-CloudOneApi GET "$baseUrl/policies/$Id"
}

# Update target policy
function Update-Policy {
    param([int]$Id, [object]$Payload)
    # Remove name to avoid duplicate name error
    if ($Payload.PSObject.Properties['name']) {
        $Payload.PSObject.Properties.Remove('name')
    }
    $result = Invoke-CloudOneApi POST "$baseUrl/policies/$Id" $Payload
    Write-Host "Response:" -ForegroundColor Cyan
    $result | ConvertTo-Json -Depth 10 | Write-Host
}

# Main logic
$srcName = "Prepared_Policy"
$tgtPath = @("Base Policy", "Windows", "Windows Server")
$srcId = Get-PolicyIdByName $srcName
$tgtId = Get-PolicyIdByPath $tgtPath
$srcDetails = Get-PolicyDetails $srcId
Update-Policy $tgtId $srcDetails
Write-Host "Policy deployment completed." -ForegroundColor Green
