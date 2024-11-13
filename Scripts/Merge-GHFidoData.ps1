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

    $ValidVendorsData = Get-Content -Raw -Path $ValidVendorsFilePath | ConvertFrom-Json
    $ValidVendors = $ValidVendorsData.vendors

    # Initialize variables
    $keysNowValid = [ref]@()
    $vendorsNowValid = [ref]@()
    $changesDetected = [ref]$false
    $updateDatabaseLastUpdated = $false

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

    # Index existing JSON data by AAGUID
    $jsonDataByAAGUID = @{}
    foreach ($jsonItem in $jsonData.keys) {
        $jsonDataByAAGUID[$jsonItem.AAGUID] = $jsonItem
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
    $urlDataByAAGUID = @{}
    foreach ($urlItem in $urlData) {
        $urlDataByAAGUID[$urlItem.AAGUID] = $urlItem
    }

    $logDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    # Read existing log content
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
    $markdownContent = [ref]@()
    $detailedLogContent = [ref]@("Detailed Log - $logDate")
    $issueEntries = [ref]@()
    $envFilePath = "$PSScriptRoot/env_vars.txt"
    $loggedInvalidVendors = [ref]@()
    $existingLogEntries = @()
    $currentLogEntries = @()

    # Parse existing markdown content to extract last log entries
    if ($existingMarkdownContent -ne "") {
        # Split the content into sections based on the header
        $logSections = $existingMarkdownContent -split "(?m)^# Merge Log - \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
        if ($logSections.Count -gt 1) {
            # The first element may be empty due to split behavior
            $lastLogEntries = $logSections[1] -split "`r?`n"
            $existingLogEntries = $lastLogEntries | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        }
    }

    # Merge data and handle vendors
    foreach ($urlItem in $urlData) {
        # Create mutable object
        $hash = [ordered]@{}
        foreach ($prop in $urlItem.PSObject.Properties) {
            $hash[$prop.Name] = $prop.Value
        }

        $aaguid = $hash['AAGUID']
        $description = $hash['Description']
        $vendor = ""  # Vendor from URL data is always blank

        # Check if AAGUID exists in existing JSON data
        if ($jsonDataByAAGUID.ContainsKey($aaguid)) {
            # Existing entry - use Vendor from JSON data
            $existingItem = $jsonDataByAAGUID[$aaguid]

            # Ensure mutable
            $existingHash = [ordered]@{}
            foreach ($prop in $existingItem.PSObject.Properties) {
                $existingHash[$prop.Name] = $prop.Value
            }

            # Get Vendor from existing JSON data
            $vendor = $existingHash['Vendor']  # This may be null or empty

            # Store the original vendor before validation
            $originalVendor = $vendor

            # Prepare vendor as [ref] to allow updates from the function
            $vendorRef = [ref]$vendor

            # Validate Vendor
            $validVendor = Test-GHValidVendor -vendor $vendorRef -description $description -aaguid $aaguid -ValidVendors $ValidVendors -markdownContent $markdownContent -detailedLogContent $detailedLogContent -loggedInvalidVendors $loggedInvalidVendors -issueEntries $issueEntries -existingLogEntries $existingLogEntries -changesDetected $changesDetected

            # Update vendor variable if it was changed in the function
            $vendor = $vendorRef.Value

            # Check if vendor has changed (correction occurred)
            if ($vendor -ne $originalVendor) {
                $changesDetected.Value = $true
                $updateDatabaseLastUpdated = $true
            }

            # Retrieve the existing 'ValidVendor' status
            $existingValidVendor = if ($existingItem) { $existingItem.ValidVendor } else { 'No' }

            # Compare the existing and new 'ValidVendor' status
            if (($existingValidVendor -eq 'No' -or [string]::IsNullOrEmpty($existingValidVendor)) -and $validVendor -eq 'Yes') {
                # Key has become valid
                $keysNowValid.Value += $aaguid
                $changesDetected.Value = $true
                $updateDatabaseLastUpdated = $true

                # Prepare log entry
                $logEntry = "Vendor '$vendor' for description '$description' has become valid."
                $currentLogEntries += $logEntry
                $detailedLogContent.Value += "`n$logEntry"
            }

            # Check for changes in specific properties
            $propertiesToCheck = @('Description', 'Bio', 'USB', 'NFC', 'BLE')
            foreach ($property in $propertiesToCheck) {
                if ($existingHash[$property] -ne $hash[$property]) {
                    $changesDetected.Value = $true
                    $updateDatabaseLastUpdated = $true  # Update when property changes
                    $logEntry = "Property '$property' for AAGUID '$aaguid' changed from '$($existingHash[$property])' to '$($hash[$property])'."
                    $currentLogEntries += $logEntry
                    $detailedLogContent.Value += "`n$logEntry"
                }
            }

            # Update the existing hash with the desired property order
            $existingHash = [ordered]@{
                Vendor      = $vendor
                Description = $description
                AAGUID      = $aaguid
                Bio         = $hash['Bio']
                USB         = $hash['USB']
                NFC         = $hash['NFC']
                BLE         = $hash['BLE']
                ValidVendor = $validVendor
            }

            $mergedData.keys += [PSCustomObject]$existingHash
        }
        else {
            # New entry
            $vendor = ""  # Leave Vendor as empty
            $validVendor = 'No'

            # Create a hashtable for new item with desired property order
            $itemHash = [ordered]@{
                Vendor      = $vendor
                Description = $description
                AAGUID      = $hash['AAGUID']
                Bio         = $hash['Bio']
                USB         = $hash['USB']
                NFC         = $hash['NFC']
                BLE         = $hash['BLE']
                ValidVendor = $validVendor
            }

            $mergedData.keys += [PSCustomObject]$itemHash
            $changesDetected.Value = $true
            $updateDatabaseLastUpdated = $true

            # Log that a new entry without Vendor has been added
            #$logEntry = "New entry added for description '$description', but Vendor information is missing."
            #$currentLogEntries += $logEntry
            #$detailedLogContent.Value += "`n$logEntry"
        }

        # Collect current invalid vendors for comparison
        if ($validVendor -eq "No") {
            $invalidVendorEntry = "Invalid vendor detected for AAGUID '$aaguid' with description '$description'. Vendor '$vendor' is not in the list of valid vendors."
            $currentLogEntries += $invalidVendorEntry
            $detailedLogContent.Value += "`n$invalidVendorEntry"
        }
    }

    # Handle removed entries (no issues created)
    foreach ($jsonItem in $jsonData.keys) {
        if (-not $urlDataByAAGUID.ContainsKey($jsonItem.AAGUID)) {
            $logEntry = "Entry removed for description '$($jsonItem.Description)'"
            $currentLogEntries += $logEntry
            $detailedLogContent.Value += "`n$logEntry"
            $changesDetected.Value = $true
            $updateDatabaseLastUpdated = $true
        }
    }

    # Update metadata
    if ($updateDatabaseLastUpdated) {
        $mergedData.metadata.databaseLastUpdated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    $mergedData.metadata.databaseLastChecked = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

    # Write the merged data
    $jsonOutput = $mergedData | ConvertTo-Json -Depth 10

    # Write to the JSON file
    Set-Content -Path $JsonFilePath -Value $jsonOutput -Encoding utf8

    # Compare current log entries with existing log entries
    $newChanges = $false
    if ($currentLogEntries.Count -ne $existingLogEntries.Count) {
        $newChanges = $true
    }
    else {
        for ($i = 0; $i -lt $currentLogEntries.Count; $i++) {
            if ($currentLogEntries[$i] -ne $existingLogEntries[$i]) {
                $newChanges = $true
                break
            }
        }
    }

    # Write to merge_log.md only if there are new changes
    if ($newChanges -and $currentLogEntries.Count -gt 0) {
        $newMergeContent = "# Merge Log - $logDate`n`n" + 
                            ($currentLogEntries -join "`n`n") + 
        "`n`n`n" + 
        $existingMarkdownContent.Trim()
        Set-Content -Path $MarkdownFilePath -Value $newMergeContent -Encoding utf8
    }
    else {
        Write-Host "No new entries to add to merge_log.md."
    }

    # If no entries were added, add a default message
    if ($detailedLogContent.Value.Count -eq 1) {
        $detailedLogContent.Value += "`nNo changes detected during this run."
    }

    # Always write to detailed_log.txt
    $detailedLogContent.Value = $detailedLogContent.Value.TrimEnd("`n", "`r")
    $newDetailedContent = $detailedLogContent.Value + "`n`n" + $existingDetailedLogContent.TrimStart("`n", "`r")

    Set-Content -Path $DetailedLogFilePath -Value $newDetailedContent -Encoding utf8

    # Write issue entries to the environment variables file
    if ($issueEntries.Value -and $issueEntries.Value.Count -gt 0) {
        $issueEntriesString = $issueEntries.Value -join "`n"
        # Escape special characters for GitHub Actions
        if ($null -ne $issueEntriesString -and $issueEntriesString -ne "") {
            $issueEntriesEscaped = $issueEntriesString.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A').Replace("'", '%27').Replace('"', '%22')
            "ISSUE_ENTRIES=$issueEntriesEscaped" | Out-File -FilePath $envFilePath -Encoding utf8 -Append
        }
    }

    # Write keys now valid to the environment variables file
    if ($keysNowValid -and $keysNowValid.Value -and $keysNowValid.Value.Count -gt 0) {
        $keysNowValidString = $keysNowValid.Value | Select-Object -Unique | Sort-Object
        $keysNowValidString = $keysNowValidString -join "`n"
        # Escape special characters for GitHub Actions
        if ($null -ne $keysNowValidString -and $keysNowValidString -ne "") {
            $keysNowValidEscaped = $keysNowValidString.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A').Replace("'", '%27').Replace('"', '%22')
            "KEYS_NOW_VALID=$keysNowValidEscaped" | Out-File -FilePath $envFilePath -Encoding utf8 -Append
        }
    }
}

# Call the function
Merge-GHFidoData