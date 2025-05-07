<#
.SYNOPSIS
    Tags all devices in a specific Entra ID group in Microsoft Defender for Endpoint.
.DESCRIPTION
    This script uses interactive authentication to connect to Microsoft Graph and 
    Microsoft Defender for Endpoint, then tags devices from an Entra ID group.
.PARAMETER GroupId
    The ID of the Entra ID group containing the devices to tag.
.PARAMETER TagName
    The tag to apply in Microsoft Defender for Endpoint.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$GroupId,
    
    [Parameter(Mandatory=$true)]
    [string]$TagName
)

# Check if Microsoft Graph modules are installed
$requiredModules = @(
    "Microsoft.Graph.Authentication", 
    "Microsoft.Graph.Groups", 
    "Microsoft.Graph.Identity.DirectoryManagement"
)

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module..." -ForegroundColor Yellow
        Install-Module -Name $module -Force -Scope CurrentUser
    }
}

# Import modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement

# Check if MSAL.PS module is installed for authentication
if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
    Write-Host "Installing MSAL.PS module..." -ForegroundColor Yellow
    Install-Module MSAL.PS -Scope CurrentUser -Force
}
Import-Module MSAL.PS

# Clear MSAL token cache to avoid authentication issues
try {
    Clear-MsalTokenCache | Out-Null
    Write-Host "MSAL token cache cleared" -ForegroundColor Green
}
catch {
    Write-Host "Failed to clear MSAL token cache: $_" -ForegroundColor Yellow
    Write-Host "Continuing anyway..." -ForegroundColor Yellow
}

# Connect to Microsoft Graph with interactive authentication
try {
    Connect-MgGraph -Scopes "Group.Read.All", "Device.Read.All" -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
} 
catch {
    Write-Host "Failed to connect to Microsoft Graph: $_" -ForegroundColor Red
    exit 1
}

# Get tenant ID from current connection
$tenantId = (Get-MgContext).TenantId
Write-Host "Connected to tenant: $tenantId" -ForegroundColor Green

# Verify the group exists
try {
    $group = Get-MgGroup -GroupId $GroupId
    Write-Host "Found group: $($group.DisplayName)" -ForegroundColor Green
}
catch {
    Write-Host "Error finding group with ID $GroupId. Please verify the Group ID is correct." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Get devices from the group
try {
    Write-Host "Getting devices from group $($group.DisplayName)..." -ForegroundColor Cyan
    $groupMembers = Get-MgGroupMember -GroupId $GroupId -All
    
    # Filter to get only devices
    $devices = @()
    foreach ($member in $groupMembers) {
        if ($member.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.device") {
            # Get full device details
            $device = Get-MgDevice -DeviceId $member.Id
            $devices += $device
        }
    }
    
    Write-Host "Found $($devices.Count) devices in the group" -ForegroundColor Green
    
    if ($devices.Count -eq 0) {
        Write-Host "No devices found in the group. Exiting." -ForegroundColor Yellow
        Disconnect-MgGraph | Out-Null
        exit 0
    }
}
catch {
    Write-Host "Error getting devices from group: $_" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Get token for Microsoft Defender for Endpoint using interactive authentication
Write-Host "Getting token for Microsoft Defender for Endpoint..." -ForegroundColor Cyan
try {
    $msalParams = @{
        ClientId    = "1950a258-227b-4e31-a9cf-717495945fc2" # Microsoft Graph PowerShell App
        TenantId    = $tenantId
        Scopes      = "https://api.securitycenter.microsoft.com/.default"
        Interactive = $true
    }
    
    $msalToken = Get-MsalToken @msalParams
    $mdeToken = $msalToken.AccessToken
    
    $mdeHeaders = @{
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
        'Authorization' = "Bearer $mdeToken"
    }
    
    Write-Host "Successfully acquired token for Microsoft Defender for Endpoint" -ForegroundColor Green
}
catch {
    Write-Host "Failed to get token for Microsoft Defender for Endpoint: $_" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Get all devices from MDE
Write-Host "Getting devices from Microsoft Defender for Endpoint..." -ForegroundColor Cyan
$mdeDevices = @()
$url = "https://api.securitycenter.microsoft.com/api/machines"

try {
    do {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $mdeHeaders
        $mdeDevices += $response.value
        $url = $response.'@odata.nextLink'
    } while ($url)
    
    Write-Host "Found $($mdeDevices.Count) devices in Microsoft Defender for Endpoint" -ForegroundColor Green
}
catch {
    Write-Host "Error retrieving devices from Microsoft Defender for Endpoint: $_" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Match the Entra ID devices with MDE devices
$matchedDevices = @()
$unmatchedDevices = @()

foreach ($device in $devices) {
    $found = $false
    
    foreach ($mdeDevice in $mdeDevices) {
        if ($mdeDevice.computerDnsName -eq $device.DisplayName) {
            $matchedDevices += [PSCustomObject]@{
                DeviceName = $device.DisplayName
                DeviceId = $device.Id
                MDEId = $mdeDevice.id
            }
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        $unmatchedDevices += $device.DisplayName
    }
}

Write-Host "Matched $($matchedDevices.Count) devices between Entra ID and MDE" -ForegroundColor Green

if ($matchedDevices.Count -eq 0) {
    Write-Host "No devices could be matched. Please verify the devices are onboarded to Microsoft Defender for Endpoint." -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    exit 0
}

if ($unmatchedDevices.Count -gt 0) {
    Write-Host "$($unmatchedDevices.Count) devices could not be found in MDE:" -ForegroundColor Yellow
    foreach ($device in $unmatchedDevices) {
        Write-Host "- $device" -ForegroundColor Yellow
    }
}

# Confirm before tagging
$confirmation = Read-Host -Prompt "Ready to tag $($matchedDevices.Count) devices with tag '$TagName'. Continue? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled by user" -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    exit 0
}

# Tag each matched device in MDE
$successCount = 0
$failCount = 0

foreach ($device in $matchedDevices) {
    Write-Host "Tagging device $($device.DeviceName) with tag '$TagName'..." -ForegroundColor Cyan
    
    $url = "https://api.securitycenter.microsoft.com/api/machines/$($device.MDEId)/tags"
    $body = @{
        'Value' = $TagName
        'Action' = 'Add'
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $url -Headers $mdeHeaders -Body $body
        Write-Host "Successfully tagged device $($device.DeviceName)" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "Failed to tag device $($device.DeviceName): $_" -ForegroundColor Red
        $failCount++
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph | Out-Null

# Output summary
Write-Host "`nTag operation completed:" -ForegroundColor Blue
Write-Host "  - Successfully tagged: $successCount devices" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  - Failed to tag: $failCount devices" -ForegroundColor Red
} else {
    Write-Host "  - Failed to tag: $failCount devices" -ForegroundColor Green
}
if ($unmatchedDevices.Count -gt 0) {
    Write-Host "  - Devices not found in MDE: $($unmatchedDevices.Count)" -ForegroundColor Yellow
}

# Provide KQL query instruction
Write-Host "`nYou can use the following KQL condition in Microsoft Defender for Endpoint or Azure Sentinel to filter these tagged devices:" -ForegroundColor Cyan
Write-Host "`nDeviceDynamicTags contains `"$TagName`" or RegistryDeviceTag contains `"$TagName`" or DeviceManualTags contains `"$TagName`"" -ForegroundColor White

Write-Host "`nThis condition helps filter out devices that don't have the tag '$TagName' applied." -ForegroundColor Cyan