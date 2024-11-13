<#
.SYNOPSIS
    Validates the vendor of a FIDO key against a list of valid vendors.

.DESCRIPTION
    The `Test-GHValidVendor` function checks if the provided vendor is in the list of valid vendors. If the vendor is not valid, it attempts to use the first word of the description as the vendor. If the vendor is still not valid, it logs the invalid vendor and prepares an issue entry.

.PARAMETER vendor
    [ref] The vendor of the FIDO key to be validated.

.PARAMETER description
    [string] The description of the FIDO key.

.PARAMETER aaguid
    [string] The AAGUID of the FIDO key.

.PARAMETER ValidVendors
    [string[]] The list of valid vendors.

.PARAMETER markdownContent
    [ref] The markdown content to be updated with log entries.

.PARAMETER detailedLogContent
    [ref] The detailed log content to be updated with log entries.

.PARAMETER loggedInvalidVendors
    [ref] The list of logged invalid vendors.

.PARAMETER issueEntries
    [ref] The list of issue entries to be created.

.PARAMETER existingLogEntries
    [string[]] The list of existing log entries to avoid duplicates.

.PARAMETER changesDetected
    [ref] A flag indicating if any changes were detected.

.EXAMPLE
    $vendor = [ref]"UnknownVendor"
    $description = "UnknownVendor FIDO2 Key"
    $aaguid = "12345678-1234-1234-1234-123456789012"
    $ValidVendors = @("Yubico", "Feitian", "Google")
    $markdownContent = [ref]""
    $detailedLogContent = [ref]""
    $loggedInvalidVendors = [ref]@()
    $issueEntries = [ref]@()
    $existingLogEntries = @()
    $changesDetected = [ref]$false

    Test-GHValidVendor -vendor $vendor -description $description -aaguid $aaguid -ValidVendors $ValidVendors -markdownContent $markdownContent -detailedLogContent $detailedLogContent -loggedInvalidVendors $loggedInvalidVendors -issueEntries $issueEntries -existingLogEntries $existingLogEntries -changesDetected $changesDetected

.NOTES
    The function reads the list of valid vendors from a JSON file located at "Assets/valid_vendors.json".
#>
function Test-GHValidVendor {
    param (
        [Parameter(Mandatory = $true)]
        [ref]$vendor,
        [Parameter(Mandatory = $true)]
        [string]$description,
        [Parameter(Mandatory = $true)]
        [string]$aaguid,
        [string[]]$ValidVendors,
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
