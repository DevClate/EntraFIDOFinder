function Test-GHValidVendor {
    param (
        [Parameter(Mandatory = $true)]
        [ref]$vendor,
        [Parameter(Mandatory = $true)]
        [string]$description,
        [Parameter(Mandatory = $true)]
        [string]$aaguid,
        [string[]]$ValidVendors, # Added this parameter
        [ref]$markdownContent,
        [ref]$detailedLogContent,
        [ref]$loggedInvalidVendors,
        [ref]$issueEntries,
        [string[]]$existingLogEntries,
        [ref]$changesDetected
    )

    $validVendorsFilePath = "Assets/valid_vendors.json"
    if (-Not (Test-Path -Path $validVendorsFilePath)) {
        Write-Error "The valid vendors JSON file was not found at path: $validVendorsFilePath"
        return "No"
    }
    
    if ($ValidVendors -contains $vendor.Value) {
        return "Yes"
    }
    else {
        # Attempt to use the first word of the description as the vendor
        $firstWord = ($description -split ' ')[0]
        if ($firstWord -and $firstWord -ne $vendor.Value) {
            Write-Host "Vendor '$($vendor.Value)' is invalid. Trying first word of description '$firstWord' as vendor."
            if ($ValidVendors -contains $firstWord) {
                # Update vendor to first word and return Yes
                Write-Host "Vendor '$firstWord' is valid."
                $vendor.Value = $firstWord
                $logEntry = "Vendor corrected for AAGUID '$aaguid': '$($vendor.Value)' to '$firstWord'."
                $detailedLogContent.Value += "`n$logEntry"
                Write-Host "Added log entry for vendor correction: $logEntry"
                $changesDetected.Value = $true
                return "Yes"
            }
        }
        # Log invalid vendor for the specific key
        $logEntry = "Invalid vendor detected for AAGUID '$aaguid' with description '$description'. Vendor '$($vendor.Value)' is not in the list of valid vendors."
        $logEntryTrimmed = $logEntry.Trim()
    
        if (-not ($existingLogEntries -contains $logEntryTrimmed)) {
            $markdownContent.Value += "$logEntry"
            $detailedLogContent.Value += "`n$logEntry"
            Write-Host "Added log entry for invalid vendor: $logEntry"
            $changesDetected.Value = $true
    
            # Prepare issue entry with AAGUID included in the title
            $issueTitle = "Invalid Vendor Detected for AAGUID $aaguid : $($vendor.Value)"
            $issueBody = $logEntry
            $issueEntries.Value += "$issueTitle|$issueBody|InvalidVendor"
        }
        return "No"
    }
}
