function Test-GHValidVendor {
    <#
    .SYNOPSIS
    Tests if a vendor is valid based on a list of valid vendors.

    .DESCRIPTION
    This function checks if the provided vendor is in the list of valid vendors. If not, it attempts to use the first word of the description as the vendor. 
    If the vendor is still invalid and it's a new entry, it logs the invalid vendor and prepares an issue entry.

    .PARAMETER vendor
    [ref] The vendor to be validated.

    .PARAMETER description
    [string] The description associated with the vendor.

    .PARAMETER aaguid
    [string] The AAGUID associated with the vendor.

    .PARAMETER ValidVendors
    [string[]] The list of valid vendors.

    .PARAMETER markdownContent
    [System.Collections.ArrayList] The collection to store markdown log entries.

    .PARAMETER detailedLogContent
    [System.Collections.ArrayList] The collection to store detailed log entries.

    .PARAMETER loggedInvalidVendors
    [System.Collections.ArrayList] The collection to store logged invalid vendors.

    .PARAMETER issueEntries
    [System.Collections.ArrayList] The collection to store issue entries.

    .PARAMETER existingLogEntries
    [string[]] The list of existing log entries.

    .PARAMETER changesDetected
    [ref] Indicates if any changes were detected.

    .PARAMETER IsNewEntry
    [bool] Indicates if the entry is new.

    .PARAMETER currentLogEntries
    [System.Collections.ArrayList] The collection to store current log entries.

    .OUTPUTS
    [string] Returns "Yes" if the vendor is valid or corrected, otherwise returns "No".

    .EXAMPLE
    $vendor = [ref] "SomeVendor"
    $description = "Some description"
    $aaguid = "1234-5678-9012"
    $ValidVendors = @("ValidVendor1", "ValidVendor2")
    $markdownContent = [System.Collections.ArrayList]::new()
    $detailedLogContent = [System.Collections.ArrayList]::new()
    $loggedInvalidVendors = [System.Collections.ArrayList]::new()
    $issueEntries = [System.Collections.ArrayList]::new()
    $existingLogEntries = @()
    $changesDetected = [ref] $false
    $IsNewEntry = $true
    $currentLogEntries = [System.Collections.ArrayList]::new()

    Test-GHValidVendor -vendor $vendor -description $description -aaguid $aaguid -ValidVendors $ValidVendors -markdownContent $markdownContent -detailedLogContent $detailedLogContent -loggedInvalidVendors $loggedInvalidVendors -issueEntries $issueEntries -existingLogEntries $existingLogEntries -changesDetected $changesDetected -IsNewEntry $IsNewEntry -currentLogEntries $currentLogEntries
    #>

    param (
        [Parameter(Mandatory = $true)]
        [ref]$vendor,
        [Parameter(Mandatory = $true)]
        [string]$description,
        [Parameter(Mandatory = $true)]
        [string]$aaguid,
        [string[]]$ValidVendors,
        [System.Collections.ArrayList]$markdownContent,
        [System.Collections.ArrayList]$detailedLogContent,
        [System.Collections.ArrayList]$loggedInvalidVendors,
        [System.Collections.ArrayList]$issueEntries,
        [string[]]$existingLogEntries,
        [ref]$changesDetected,
        [bool]$IsNewEntry,
        [System.Collections.ArrayList]$currentLogEntries
    )

    # Check if the vendor is valid
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
                $oldVendor = $vendor.Value
                $vendor.Value = $firstWord
                $logEntry = "Vendor corrected for AAGUID '$aaguid': '$oldVendor' to '$firstWord'."
                $detailedLogContent.Add("")
                $detailedLogContent.Add($logEntry)
                Write-Host "Added log entry for vendor correction: $logEntry"
                $changesDetected.Value = $true
                return "Yes"
            }
        }
        
        # Try to match against valid vendors case-insensitively
        foreach ($validVendor in $ValidVendors) {
            if ($description -match $validVendor) {
                # Found a valid vendor in the description
                Write-Host "Found valid vendor '$validVendor' in description for AAGUID '$aaguid'."
                $oldVendor = $vendor.Value
                $vendor.Value = $validVendor
                $logEntry = "Vendor updated for AAGUID '$aaguid': '$oldVendor' to '$validVendor' from description match."
                $detailedLogContent.Add("")
                $detailedLogContent.Add($logEntry)
                Write-Host "Added log entry for vendor correction: $logEntry"
                $changesDetected.Value = $true
                return "Yes"
            }
        }

        # Log invalid vendor for the specific key if it's a new entry
        if ($IsNewEntry) {
            $logEntry = "Invalid vendor detected for AAGUID '$aaguid' with description '$description'. Vendor '$($vendor.Value)' is not in the list of valid vendors."
            $logEntryTrimmed = $logEntry.Trim()
        
            if (-not ($existingLogEntries -contains $logEntryTrimmed)) {
                $markdownContent.Add($logEntry)
                $detailedLogContent.Add("")
                $detailedLogContent.Add($logEntry)
                Write-Host "Added log entry for invalid vendor: $logEntry"

                # Add log entry to currentLogEntries
                $currentLogEntries.Add($logEntry)

                # Set changesDetected to true
                $changesDetected.Value = $true
        
                # Prepare issue entry with AAGUID included in the title
                $issueTitle = "Invalid Vendor Detected for AAGUID $aaguid : $($vendor.Value)"
                $issueBody = $logEntry
                $issueEntries.Add("$issueTitle|$issueBody|InvalidVendor")
            }
        }
        return "No"
    }
}