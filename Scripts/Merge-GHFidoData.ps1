<#
.SYNOPSIS
    Merges FIDO key data from a URL with existing JSON data and logs any changes.

.DESCRIPTION
    Fetches FIDO key data from the specified URL and merges it with local JSON data.
    Handles updates, additions, and removals of keys, validates vendors, and logs changes.
    Updates metadata and environment variables for GitHub Actions.

.PARAMETER Url
    The URL to fetch FIDO key data from.
    Defaults to Microsoft's hardware vendor page.

.PARAMETER JsonFilePath
    The path to the local JSON file containing existing FIDO key data.
    Default is 'Assets/FidoKeys.json'.

.PARAMETER MarkdownFilePath
    The path to the markdown file for logging merge results.
    Default is 'merge_log.md'.

.PARAMETER DetailedLogFilePath
    The path to the detailed log file.
    Default is 'detailed_log.txt'.

.PARAMETER ValidVendorsFilePath
    The path to the JSON file containing valid vendors.
    Default is 'Assets/valid_vendors.json'.

.EXAMPLE
    Merge-GHFidoData

.NOTES
    Author: Clayton Tyger
    Date: 12-01-2024
#>

Function Merge-GHFidoData {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Url = "https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor",
        [Parameter()]
        [string]$JsonFilePath = "Assets/FidoKeys.json",
        [Parameter()]
        [string]$MarkdownFilePath = "merge_log.md",
        [Parameter()]
        [string]$DetailedLogFilePath = "detailed_log.txt",
        [Parameter()]
        [string]$ValidVendorsFilePath = "Assets/valid_vendors.json"
    )

    $ErrorActionPreference = 'Stop'
    
    # Load existing JSON data
    try {
        if (-not (Test-Path -Path $JsonFilePath)) {
            $jsonData = @{
                metadata = @{
                    databaseLastChecked = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    databaseLastUpdated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                }
                keys     = @()
            }
        }
        else {
            $jsonData = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
        }
    }
    catch {
        Write-Error "Failed to load JSON data: $_"
        return
    }

    # Load valid vendors data
    try {
        $ValidVendors = (Get-Content -Raw -Path $ValidVendorsFilePath | ConvertFrom-Json).vendors
    }
    catch {
        Write-Error "Failed to load valid vendors data: $_"
        return
    }

    # Initialize variables
    $changesDetected = [ref]$false
    $updateDatabaseLastUpdated = $false
    $changesAreSame = $false
    $keysNowValid = New-Object System.Collections.ArrayList
    $issueEntries = New-Object System.Collections.ArrayList
    $loggedInvalidVendors = New-Object System.Collections.ArrayList
    $currentLogEntries = New-Object System.Collections.ArrayList

    # Import the Test-GHValidVendor function
    . "$PSScriptRoot\Test-GHValidVendor.ps1"

    # Initialize merged data
    $mergedData = @{
        metadata = @{
            databaseLastChecked = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            databaseLastUpdated = $jsonData.metadata.databaseLastUpdated
        }
        keys     = @()
    }

    # Initialize an empty hashtable
    $jsonDataByAAGUID = @{}

    # Populate the hashtable with AAGUIDs as keys and single items as values
    foreach ($key in $jsonData.keys) {
        $jsonDataByAAGUID[$key.AAGUID] = $key
    }

    # Fetch data from URL
    try {
        $urlData = Export-GHEntraFido -Url $Url
    }
    catch {
        Write-Error "Failed to fetch data from URL: $_"
        return
    }

    # Index URL data by AAGUID
    $urlDataByAAGUID = $urlData | Group-Object -AsHashTable -Property AAGUID

    # Prepare for logging
    $logDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    # Parse existing log content
    $existingMarkdownContent = if (Test-Path -Path $MarkdownFilePath) {
        Get-Content -Raw -Path $MarkdownFilePath
    }
    else {
        ""
    }

    $existingDetailedLogContent = if (Test-Path -Path $DetailedLogFilePath) {
        Get-Content -Raw -Path $DetailedLogFilePath
    }
    else {
        ""
    }

    # Initialize content
    $markdownContent = New-Object System.Collections.ArrayList
    $detailedLogContent = New-Object System.Collections.ArrayList
    $detailedLogContent.Add("Detailed Log - $logDate") # Initialize with the log date
    $envFilePath = "$PSScriptRoot/env_vars.txt"

    # Parse existing markdown content to extract last log entries
    if ($existingMarkdownContent -ne "") {
        # Regex to match each log entry
        $pattern = "(?ms)^# Merge Log - \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s*(.*?)(?=^# Merge Log - \d{4}-\d{2}-\d{2}|\z)"
        $matches = [regex]::Matches($existingMarkdownContent, $pattern)
        if ($matches.Count -gt 0) {
            # The first match is the most recent log entries
            $lastLogEntriesSection = $matches[0].Groups[1].Value
            $existingLogEntries = $lastLogEntriesSection -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        }
    }

    # Initialize existingLogEntries as an array even if it's null or empty
    $existingLogEntries = if ($null -ne $existingLogEntries) { @($existingLogEntries) } else { @() }

    # Collect changes in a separate variable
    $detailedChanges = @()

    # Merge data and handle vendors
    foreach ($aaguid in $urlDataByAAGUID.Keys) {
        $urlItem = $urlDataByAAGUID[$aaguid]
        $description = $urlItem.Description
        $vendor = ""

        if ($jsonDataByAAGUID.ContainsKey($aaguid)) {
            # Existing entry
            $existingItem = $jsonDataByAAGUID[$aaguid]
            $vendor = $existingItem.Vendor
            $vendorRef = [ref]$vendor

            # Create a hashtable with parameters
            $ValidVendorParams = @{
                vendor               = $vendorRef
                description          = $description
                aaguid               = $aaguid
                ValidVendors         = $ValidVendors
                markdownContent      = $markdownContent
                detailedLogContent   = $detailedLogContent
                loggedInvalidVendors = $loggedInvalidVendors
                issueEntries         = $issueEntries
                existingLogEntries   = $existingLogEntries
                changesDetected      = $changesDetected
                IsNewEntry           = $false
                currentLogEntries    = $currentLogEntries
            }

            # Call the function with splatting
            $validVendor = Test-GHValidVendor @ValidVendorParams
            $vendor = $vendorRef.Value

            # Access $existingItem.Version
            $existingVersion = $existingItem.Version

            # Get the latest version from metadataStatement.authenticatorGetInfo.versions
            $latestVersion = $null
            if ($existingItem.metadataStatement?.authenticatorGetInfo?.versions) {
                $latestVersion = $existingItem.metadataStatement.authenticatorGetInfo.versions[-1]
            }

            # Compare and update the Version property if needed
            if ($latestVersion -and $existingVersion -ne $latestVersion) {
                # Update the Version property
                $existingItem.Version = $latestVersion
                $changesDetected.Value = $true
                $updateDatabaseLastUpdated = $true

                # Log the change
                $logEntry = "Updated 'Version' for AAGUID '$aaguid' from '$existingVersion' to '$latestVersion'."
                $currentLogEntries.Add($logEntry)
                $detailedChanges += $logEntry  # Collect changes separately
            }

            # Check for changes in specific properties
            $propertiesToCheck = @('Description', 'Bio', 'USB', 'NFC', 'BLE')
            foreach ($property in $propertiesToCheck) {
                $existingValue = $existingItem.$property
                $newValue = $urlItem.$property
                if ($existingValue -ne $newValue) {
                    $existingItem.$property = $newValue
                    $changesDetected.Value = $true
                    $updateDatabaseLastUpdated = $true
                    $logEntry = "Updated '$property' for AAGUID '$aaguid' from '$existingValue' to '$newValue'."
                    $currentLogEntries.Add($logEntry)
                    $detailedChanges += $logEntry  # Collect changes separately
                }
            }

            # Normalize ValidVendor values to strings
            $existingValidVendor = [string]$existingItem.ValidVendor
            $newValidVendor = [string]$validVendor

            # Update ValidVendor status if changed
            if ($existingValidVendor -ne $newValidVendor) {
                $existingItem.ValidVendor = $newValidVendor
                $changesDetected.Value = $true
                $updateDatabaseLastUpdated = $true

                if ($newValidVendor -eq 'Yes') {
                    # Always check if vendor is empty or doesn't match a valid vendor
                    if ([string]::IsNullOrWhiteSpace($vendor) -or -not ($ValidVendors -contains $vendor)) {
                        # Find the valid vendor that matches the description
                        $bestMatch = $ValidVendors | Where-Object { $description -match $_ } | Select-Object -First 1
                        
                        if ($null -ne $bestMatch) {
                            $oldVendor = $vendor
                            $vendor = $bestMatch
                            $existingItem.Vendor = $vendor
                            $logEntry = "Updated vendor name for AAGUID '$aaguid' from '$oldVendor' to '$vendor' based on validated vendor list."
                            $currentLogEntries.Add($logEntry)
                            $detailedChanges += $logEntry
                        }
                        # If still no match, try to find any valid vendor in our list to use
                        elseif ([string]::IsNullOrWhiteSpace($vendor)) {
                            # As a last resort, use the first valid vendor that appears in the description
                            foreach ($validVendorName in $ValidVendors) {
                                if ($description -match $validVendorName) {
                                    $vendor = $validVendorName
                                    $existingItem.Vendor = $vendor
                                    $logEntry = "Set vendor name for AAGUID '$aaguid' to '$vendor' based on description match."
                                    $currentLogEntries.Add($logEntry)
                                    $detailedChanges += $logEntry
                                    break
                                }
                            }
                            
                            # If still no vendor found, use the first word of the description
                            if ([string]::IsNullOrWhiteSpace($vendor)) {
                                $firstWord = ($description -split ' ')[0]
                                if (-not [string]::IsNullOrWhiteSpace($firstWord)) {
                                    $vendor = $firstWord
                                    $existingItem.Vendor = $vendor
                                    $logEntry = "Set vendor name for AAGUID '$aaguid' to '$vendor' based on first word of description."
                                    $currentLogEntries.Add($logEntry)
                                    $detailedChanges += $logEntry
                                }
                            }
                        }
                    }
                    
                    $keysNowValid.Add($aaguid)
                    $logEntry = "Vendor '$vendor' for description '$description' has become valid."
                    $currentLogEntries.Add($logEntry)
                    $detailedChanges += $logEntry
                    # Add logic to close the corresponding GitHub issue if it exists
                    $issueTitle = "Invalid Vendor Detected for AAGUID $aaguid : $vendor"
                    $existingIssue = $issueEntries | Where-Object { $_ -match [regex]::Escape($issueTitle) }
                    if ($existingIssue) {
                        $issueEntries.Add("$issueTitle|CLOSE")
                    }
                }
                elseif ($newValidVendor -eq 'No') {
                    $logEntry = "Vendor '$vendor' for description '$description' has become invalid."
                    $currentLogEntries.Add($logEntry)
                    $detailedChanges += $logEntry
                    # Create an issue when a vendor becomes invalid
                    $issueTitle = "Vendor Became Invalid for AAGUID $aaguid : $vendor"
                    $issueBody = $logEntry

                    # Check if the issue already exists
                    $existingIssue = $issueEntries | Where-Object { $_ -match [regex]::Escape($issueTitle) }
                    if (-not $existingIssue) {
                        $issueEntries.Add("$issueTitle|$issueBody|InvalidVendor")
                    }
                }
            }

            # Add updated item to merged data
            $mergedData.keys += $existingItem
        }
        else {
            # New entry
            $vendorRef = [ref]$vendor
            $ValidVendorParams = @{
                vendor               = $vendorRef
                description          = $description
                aaguid               = $aaguid
                ValidVendors         = $ValidVendors
                markdownContent      = $markdownContent
                detailedLogContent   = $detailedLogContent
                loggedInvalidVendors = $loggedInvalidVendors
                issueEntries         = $issueEntries
                existingLogEntries   = $existingLogEntries
                changesDetected      = $changesDetected
                IsNewEntry           = $true
                currentLogEntries    = $currentLogEntries
            }

            # Call the function with splatting
            $validVendor = Test-GHValidVendor @ValidVendorParams
            $vendor = $vendorRef.Value

            # If vendor is valid, ensure it matches a valid vendor name from the list
            if ($validVendor -eq 'Yes') {
                # Now check if vendor is still empty or doesn't match a valid vendor name
                if ([string]::IsNullOrWhiteSpace($vendor) -or -not ($ValidVendors -contains $vendor)) {
                    # Find the valid vendor that matches the description
                    $bestMatch = $ValidVendors | Where-Object { $description -match $_ } | Select-Object -First 1
                    
                    if ($null -ne $bestMatch) {
                        $oldVendor = $vendor
                        $vendor = $bestMatch
                        $logEntry = "Updated vendor name for new AAGUID '$aaguid' from '$oldVendor' to '$vendor' based on validated vendor list."
                        $currentLogEntries.Add($logEntry)
                        $detailedChanges += $logEntry
                    }
                    # If still no match, try to find any valid vendor in our list to use
                    elseif ([string]::IsNullOrWhiteSpace($vendor)) {
                        # As a last resort, use the first valid vendor that appears in the description
                        foreach ($validVendorName in $ValidVendors) {
                            if ($description -match $validVendorName) {
                                $vendor = $validVendorName
                                $logEntry = "Set vendor name for AAGUID '$aaguid' to '$vendor' based on description match."
                                $currentLogEntries.Add($logEntry)
                                $detailedChanges += $logEntry
                                break
                            }
                        }
                        
                        # If still no vendor found, use the first word of the description
                        if ([string]::IsNullOrWhiteSpace($vendor)) {
                            $firstWord = ($description -split ' ')[0]
                            if (-not [string]::IsNullOrWhiteSpace($firstWord)) {
                                $vendor = $firstWord
                                $logEntry = "Set vendor name for AAGUID '$aaguid' to '$vendor' based on first word of description."
                                $currentLogEntries.Add($logEntry)
                                $detailedChanges += $logEntry
                            }
                        }
                    }
                }
            }
            # If vendor is still empty but validVendor is 'No', set to "Unknown"
            elseif ([string]::IsNullOrWhiteSpace($vendor)) {
                $vendor = "Unknown"
                $logEntry = "Set vendor name for invalid AAGUID '$aaguid' to 'Unknown'."
                $currentLogEntries.Add($logEntry)
                $detailedChanges += $logEntry
            }

            $newItem = [pscustomobject]@{
                Vendor                 = $vendor
                Description            = $description
                AAGUID                 = $aaguid
                Bio                    = $urlItem.Bio
                USB                    = $urlItem.USB
                NFC                    = $urlItem.NFC
                BLE                    = $urlItem.BLE
                Version                = $urlItem.Version
                ValidVendor            = $validVendor  # This is now guaranteed to be just "Yes" or "No"
                authenticatorGetInfo   = $urlItem.authenticatorGetInfo
                statusReports          = $urlItem.statusReports
                timeOfLastStatusChange = $urlItem.timeOfLastStatusChange
            }
            $mergedData.keys += $newItem
            $changesDetected.Value = $true
            $updateDatabaseLastUpdated = $true

            # Log new entry if vendor is valid
            if ($validVendor -eq 'Yes') {
                $logEntry = "Added new entry for AAGUID '$aaguid' with description '$description' and vendor '$vendor'."
                $currentLogEntries.Add($logEntry)
                $detailedChanges += $logEntry  # Collect changes separately
            }
            # Note: Invalid vendor logging for new entries is handled inside Test-GHValidVendor
        }
    }

    # Handle removed entries
    foreach ($aaguid in $jsonDataByAAGUID.Keys) {
        if (-not $urlDataByAAGUID.ContainsKey($aaguid)) {
            $removedItem = $jsonDataByAAGUID[$aaguid]
            $logEntry = "Entry removed for description '$($removedItem.Description)' with AAGUID '$aaguid'."
            $currentLogEntries.Add($logEntry)
            $detailedChanges += $logEntry  # Collect changes separately
            $changesDetected.Value = $true
            $updateDatabaseLastUpdated = $true
        }
    }

    # Update metadata
    if ($updateDatabaseLastUpdated) {
        $mergedData.metadata.databaseLastUpdated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    $mergedData.metadata.databaseLastChecked = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

    # Sort and write the merged data
    $mergedData.keys = $mergedData.keys | Sort-Object Vendor
    $jsonOutput = $mergedData | ConvertTo-Json -Depth 10
    Set-Content -Path $JsonFilePath -Value $jsonOutput -Encoding utf8

    # Compare current log entries with last run's log entries
    if ($changesDetected.Value) {
        # Ensure both arrays are initialized
        $normalizedExistingLogEntries = @($existingLogEntries | ForEach-Object { $_.Trim() })
        $normalizedCurrentLogEntries = @($currentLogEntries | ForEach-Object { $_.Trim() })

        $differences = Compare-Object -ReferenceObject $normalizedExistingLogEntries -DifferenceObject $normalizedCurrentLogEntries | Where-Object { $_.SideIndicator -ne '==' }

        if ($differences.Count -eq 0) {
            $changesAreSame = $true
        }
    }

    # Adjust logging based on whether changes are the same as last run
    if ($changesDetected.Value -and -not $changesAreSame) {
        # Only update merge_log.md when there are new changes different from last run
        Write-Host "New changes detected. Updating merge_log.md."
        # Update merge_log.md
        $newMergeContent = "# Merge Log - $logDate`n`n" + 
                            ($currentLogEntries -join "`n`n") + 
        "`n`n`n" + 
        $existingMarkdownContent.Trim()
        Set-Content -Path $MarkdownFilePath -Value $newMergeContent -Encoding utf8
        # Update detailed_log.txt
        # Clear the existing content
        $detailedLogContent.Clear()
        $detailedLogContent.Add("DETAILED LOG - $logDate")
        $detailedLogContent.Add("")
        # Ensure collected changes are added to $detailedLogContent
        for ($i = 0; $i -lt $detailedChanges.Count; $i++) {
            $detailedLogContent.Add($detailedChanges[$i])
            if ($i -lt ($detailedChanges.Count - 1)) {
                $detailedLogContent.Add("")  # Add an empty line between entries
            }
        }
        $detailedLogContent = $detailedLogContent | ForEach-Object { $_.TrimEnd("`n", "`r") }
        # Add extra newline between entries
        $newDetailedContent = ($detailedLogContent -join "`n") + "`n`n`n`n" + $existingDetailedLogContent.TrimStart("`n", "`r")
        Set-Content -Path $DetailedLogFilePath -Value $newDetailedContent -Encoding utf8
    }
    else {
        # Do not update merge_log.md
        if (-not $changesDetected.Value) {
            Write-Host "No changes detected. Not updating merge_log.md."
        }
        elseif ($changesAreSame) {
            Write-Host "Changes are the same as the last run. Not updating merge_log.md."
        }
        # Update detailed_log.txt with "No changes detected during this run."
        $detailedLogContent.Clear()
        $detailedLogContent.Add("DETAILED LOG - $logDate")
        $detailedLogContent.Add("")
        $detailedLogContent.Add("No changes detected during this run.")
        # Add consistent spacing between entries
        $newDetailedContent = ($detailedLogContent -join "`n") + "`n`n`n`n" + $existingDetailedLogContent.TrimStart("`n", "`r")
        Set-Content -Path $DetailedLogFilePath -Value $newDetailedContent -Encoding utf8
    }

    # Update environment variables for GitHub Actions
    if ($issueEntries -and $issueEntries.Count -gt 0) {
        $issueEntriesString = $issueEntries -join "`n"
        # Escape special characters for GitHub Actions
        if ($null -ne $issueEntriesString -and $issueEntriesString -ne "") {
            $issueEntriesEscaped = $issueEntriesString.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A').Replace("'", '%27').Replace('"', '%22')
            "ISSUE_ENTRIES=$issueEntriesEscaped" | Out-File -FilePath $envFilePath -Encoding utf8 -Append
        }
    }

    # Write keys now valid to the environment variables file
    if ($keysNowValid -and $keysNowValid.Count -gt 0) {
        $keysNowValidString = $keysNowValid | Select-Object -Unique | Sort-Object
        $keysNowValidString = $keysNowValidString -join "`n"
        # Escape special characters for GitHub Actions
        if ($null -ne $keysNowValidString -and $keysNowValidString -ne "") {
            $keysNowValidEscaped = $keysNowValidString.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A').Replace("'", '%27').Replace('"', '%22')
            "KEYS_NOW_VALID=$keysNowValidEscaped" | Out-File -FilePath $envFilePath -Encoding utf8 -Append
        }
    }
}
Merge-GHFidoData
