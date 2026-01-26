<#
.SYNOPSIS
Merges FIDO data from a JSON file and a URL source, updating and validating entries.

.DESCRIPTION
The `Merge-FidoData` function reads FIDO key data from a JSON file and a URL source, merges the data, validates vendors, and logs changes. It updates the JSON file with the merged data and generates log and markdown files documenting the changes.

.PARAMETER Url
The URL to fetch the FIDO key data from. Defaults to "https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor".

.PARAMETER JsonFilePath
The file path to the JSON file containing the original FIDO key data. If not provided, a default path is constructed.

.PARAMETER LogFilePath
The file path to the log file where changes are documented. If not provided, a default path is constructed.

.PARAMETER MarkdownFilePath
The file path to the markdown file where changes are documented. If not provided, a default path is constructed.

.EXAMPLE
Merge-FidoData -JsonFilePath "C:\path\to\FidoKeys.json" -LogFilePath "C:\path\to\merge_log.txt" -MarkdownFilePath "C:\path\to\merge_log.md"

This example merges FIDO data from the specified JSON file and URL, logs changes to the specified log and markdown files, and updates the JSON file with the merged data.

.NOTES
- The function validates vendors against a predefined list and prompts for valid vendor names if necessary.
- Duplicate entries in both JSON and URL data are logged.
- The function ensures that AAGUIDs are unique in the merged data.
- Changes are logged and saved to both log and markdown files.
#>
function Merge-FidoData {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Url = "https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor",

        [Parameter()]
        [string]$JsonFilePath,

        [Parameter()]
        [string]$LogFilePath,

        [Parameter()]
        [string]$MarkdownFilePath
    )
    
    # If JsonFilePath is not provided, construct the default path
    if (-not $PSBoundParameters.ContainsKey('JsonFilePath')) {
        $parentDir = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $JsonFilePath = Join-Path -Path $parentDir -ChildPath "Assets/FidoKeys.json"
    }

    # If LogFilePath is not provided, construct the default path
    if (-not $PSBoundParameters.ContainsKey('LogFilePath')) {
        $parentDir = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $LogFilePath = Join-Path -Path $parentDir -ChildPath "merge_log.txt"
    }

    # If MarkdownFilePath is not provided, construct the default path
    if (-not $PSBoundParameters.ContainsKey('MarkdownFilePath')) {
        $parentDir = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $MarkdownFilePath = Join-Path -Path $parentDir -ChildPath "merge_log.md"
    }

    # Read the original JSON file
    if (-Not (Test-Path -Path $JsonFilePath)) {
        Write-Error "The JSON file was not found at path: $JsonFilePath"
        return
    }
    $jsonData = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json

    # Initialize a new JSON structure based on the template
    $mergedData = @{
        metadata = @{
            databaseLastUpdated = $jsonData.metadata.databaseLastUpdated
            databaseLastChecked = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        keys = @()
    }

    # Create a hash table for quick lookup of JSON data by AAGUID
    $jsonDataByAAGUID = @{}
    $jsonDuplicates = @{}
    foreach ($jsonItem in $jsonData.keys) {
        if ($jsonDataByAAGUID.ContainsKey($jsonItem.AAGUID)) {
            $jsonDuplicates[$jsonItem.AAGUID] = $jsonItem
        } else {
            $jsonDataByAAGUID[$jsonItem.AAGUID] = $jsonItem
        }
    }

    # Create a hash table for quick lookup of URL data by AAGUID
    $urlData = Export-EntraFido -Url $Url
    $urlDataByAAGUID = @{}
    $urlDuplicates = @{}
    foreach ($urlItem in $urlData) {
        if ($urlDataByAAGUID.ContainsKey($urlItem.AAGUID)) {
            $urlDuplicates[$urlItem.AAGUID] = $urlItem
        } else {
            $urlDataByAAGUID[$urlItem.AAGUID] = $urlItem
        }
    }

    # Initialize log content with current date and time
    $logDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logContent = @("Log Date: $logDate")
    $markdownContent = @("# Merge Log - $logDate`n")

    # Log duplicates in JSON data
    foreach ($duplicate in $jsonDuplicates.Keys) {
        $logEntry = "Duplicate entry found in JSON data for AAGUID $duplicate with description '$($jsonDuplicates[$duplicate].Description)'"
        $logContent += $logEntry
        $markdownContent += "$logEntry`n"
    }

    # Log duplicates in URL data
    foreach ($duplicate in $urlDuplicates.Keys) {
        $logEntry = "Duplicate entry found in URL data for AAGUID $duplicate with description '$($urlDuplicates[$duplicate].Description)'"
        $logContent += $logEntry
        $markdownContent += "$logEntry`n"
    }

    # Function to check if AAGUID exists in the merged data
    function Test-AAGUIDExists {
        param (
            [string]$aaguid,
            [array]$keys
        )
        foreach ($key in $keys) {
            if ($key.AAGUID -eq $aaguid) {
                return $true
            }
        }
        return $false
    }

    # Validated set of vendors
    $validatedVendors = @(
        "ACS", "Allthenticator", "Arculus", "AuthenTrend", "Atos", "authenton1", "Chunghwa Telecom",
        "Crayonic", "Cryptnox", "Egomet", "Ensurity", "eWBM", "Excelsecu", "Feitian", "FIDO KeyPass", "FT-JCOS",
        "Google", "GoTrust", "HID Global", "Hideez", "Hypersecu", "HYPR", "IDCore", "IDEMIA", "IDmelon", "Thales",
        "ImproveID", "KEY-ID", "KeyXentic", "KONAI", "NEOWAVE", "NXP Semiconductors", "Nymi", "OCTATCO", "OneSpan",
        "OnlyKey", "OpenSK", "Pone Biometrics", "Precision", "RSA", "SafeNet", "Yubico", "Sentry Enterprises",
        "SmartDisplayer", "SoloKeys", "Swissbit", "Taglio", "Token Ring", "TOKEN2", "Identiv", "VALMIDO", "Kensington",
        "VinCSS", "WiSECURE"
    )

    # Function to validate a vendor
    function Test-ValidVendor {
        param (
            [string]$vendor,
            [string]$description
        )
        $attempts = 0
        while ($true) {
            if ($validatedVendors -contains $vendor) {
                return $vendor
            } elseif ($vendor -eq "SKIP") {
                if ($attempts -ge 3) {
                    Write-Warning "Skipping vendor validation for '$description' after 3 attempts"
                    return $vendor
                } else {
                    Write-Warning "Vendor is currently 'SKIP'. Please enter a valid vendor."
                }
            } else {
                Write-Warning "Unknown vendor detected: $vendor"
            }
            $vendor = Read-Host "Enter a valid vendor name for '$description' or type 'SKIP' to bypass validation"
            if ($vendor -eq "") {
                return $vendor
            }
            $attempts++
        }
    }

    $changesMade = $false

   # Loop through the URL data and merge with JSON data
foreach ($urlItem in $urlData) {
    $aaguid = $urlItem.AAGUID
    $description = $urlItem.Description
    if ($jsonDataByAAGUID.ContainsKey($aaguid)) {
        # Update the entry in the new JSON with the URL value
        $jsonItem = $jsonDataByAAGUID[$aaguid]
        foreach ($field in $urlItem.PSObject.Properties.Name) {
            if ($jsonItem.$field -ne $urlItem.$field) {
                $logEntry = "Updated $field for AAGUID $aaguid with description '$description' from '$($jsonItem.$field)' to '$($urlItem.$field)'"
                $logContent += $logEntry
                $markdownContent += "$logEntry`n"
                $jsonItem.$field = $urlItem.$field
                $changesMade = $true
            }
        }
        # Validate the vendor
        $originalVendor = $jsonItem.Vendor
        $jsonItem.Vendor = Test-ValidVendor -vendor $jsonItem.Vendor -description $description
        if ($jsonItem.Vendor -ne $originalVendor) {
            $logEntry = "Updated vendor for AAGUID $($jsonItem.AAGUID) with description '$description' from '$originalVendor' to '$($jsonItem.Vendor)'"
            $logContent += $logEntry
            $markdownContent += "$logEntry`n"
            $changesMade = $true
        }
        if (-not (Test-AAGUIDExists -aaguid $jsonItem.AAGUID -keys $mergedData.keys)) {
            $mergedData.keys += [PSCustomObject]@{
                Vendor = $jsonItem.Vendor
                Description = $jsonItem.Description
                AAGUID = $jsonItem.AAGUID
                Bio = $jsonItem.Bio
                USB = $jsonItem.USB
                NFC = $jsonItem.NFC
                BLE = $jsonItem.BLE
            }
        }
    } else {
        # Prompt for vendor if not available or invalid
        $vendor = Read-Host "Enter vendor for new AAGUID $aaguid with description '$description'"
        $vendor = Test-ValidVendor -vendor $vendor -description $description
        $urlItem | Add-Member -MemberType NoteProperty -Name Vendor -Value $vendor
        if (-not (Test-AAGUIDExists -aaguid $urlItem.AAGUID -keys $mergedData.keys)) {
            $mergedData.keys += [PSCustomObject]@{
                Vendor = $urlItem.Vendor
                Description = $urlItem.Description
                AAGUID = $urlItem.AAGUID
                Bio = $urlItem.Bio
                USB = $urlItem.USB
                NFC = $urlItem.NFC
                BLE = $urlItem.BLE
            }
            $changesMade = $true
        }
        $logEntry = "Added new AAGUID $aaguid with description '$description' and vendor $vendor"
        $logContent += $logEntry
        $markdownContent += "$logEntry`n"
    }
}

# Check for AAGUIDs in JSON data but not in URL data and remove them
foreach ($jsonItem in $jsonData.keys) {
    if (-not $urlDataByAAGUID.ContainsKey($jsonItem.AAGUID)) {
        $logEntry = "Removed AAGUID $($jsonItem.AAGUID) with description '$($jsonItem.Description)' from JSON data"
        $logContent += $logEntry
        $markdownContent += "$logEntry`n"
        $changesMade = $true
    } else {
        $originalVendor = $jsonItem.Vendor
        $jsonItem.Vendor = Test-ValidVendor -vendor $jsonItem.Vendor -description $jsonItem.Description
        if ($jsonItem.Vendor -ne $originalVendor) {
            $logEntry = "Updated vendor for AAGUID $($jsonItem.AAGUID) with description '$($jsonItem.Description)' from '$originalVendor' to '$($jsonItem.Vendor)'"
            $logContent += $logEntry
            $markdownContent += "$logEntry`n"
            $changesMade = $true
        }
        if (-not (Test-AAGUIDExists -aaguid $jsonItem.AAGUID -keys $mergedData.keys)) {
            $mergedData.keys += [PSCustomObject]@{
                Vendor = $jsonItem.Vendor
                Description = $jsonItem.Description
                AAGUID = $jsonItem.AAGUID
                Bio = $jsonItem.Bio
                USB = $jsonItem.USB
                NFC = $jsonItem.NFC
                BLE = $jsonItem.BLE
            }
        }
    }
}

# Update the databaseLastUpdated field if changes were made
if ($changesMade) {
    $mergedData.metadata.databaseLastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# Save the new JSON structure back to the original JSON file
$mergedData | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonFilePath

# Compare current markdown content with the last one
$lastMarkdownContent = if (Test-Path -Path $MarkdownFilePath) { Get-Content -Raw -Path $MarkdownFilePath } else { "" }
$currentMarkdownContent = $markdownContent -join "`n"

# Save the markdown content to the markdown file if there are changes and it's different from the last one
if ($changesMade -and $currentMarkdownContent -ne $lastMarkdownContent) {
    if (Test-Path -Path $MarkdownFilePath) {
        $markdownContent | Out-File -FilePath $MarkdownFilePath -Append
    } else {
        $markdownContent | Out-File -FilePath $MarkdownFilePath
    }
    Write-Host "Markdown log saved to $MarkdownFilePath"
} else {
    $logContent += "No changes"
    Write-Host "No changes detected, Markdown log not updated"
}

# Always save the log content to the log file
$logContent | Out-File -FilePath $LogFilePath -Append
Write-Host "Log file saved to $LogFilePath"

Write-Host "Merged data saved to $JsonFilePath"
}