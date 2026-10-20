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
        [AllowEmptyString()]
        [string]$description,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$aaguid,
        [string[]]$ValidVendors = @(),
        [System.Collections.ArrayList]$markdownContent = [System.Collections.ArrayList]::new(),
        [System.Collections.ArrayList]$detailedLogContent = [System.Collections.ArrayList]::new(),
        [System.Collections.ArrayList]$loggedInvalidVendors = [System.Collections.ArrayList]::new(),
        [System.Collections.ArrayList]$issueEntries = [System.Collections.ArrayList]::new(),
        [string[]]$existingLogEntries = @(),
        [ref]$changesDetected = ([ref]$false),
        [bool]$IsNewEntry,
        [System.Collections.ArrayList]$currentLogEntries = [System.Collections.ArrayList]::new()
    )

    # First word of the description, with the "Yubikey" -> "Yubico" exception
    function Get-FirstWordCandidate {
        param([string]$Text)
        $word = ($Text -split ' ')[0]
        if ($word -imatch '^Yubikey$') {
            Write-Host "First word is '$word', converting to 'Yubico' as vendor."
            $word = 'Yubico'
        }
        return $word
    }

    # First valid vendor whose name appears (literally, case-insensitive) in the description
    function Find-VendorInDescription {
        param([string]$Text, [string[]]$Vendors)
        foreach ($name in $Vendors) {
            if ($name -and $Text -match [regex]::Escape($name)) { return $name }
        }
        return $null
    }

    # Handle empty or null vendor explicitly
    if ([string]::IsNullOrWhiteSpace($vendor.Value)) {
        Write-Host "Vendor is empty for AAGUID '$aaguid' with description '$description'. Attempting to derive vendor from description."
        $logEntry = "Empty vendor detected for AAGUID '$aaguid' with description '$description'."
        [void]$detailedLogContent.Add("")
        [void]$detailedLogContent.Add($logEntry)

        # Attempt to use the first word of the description as the vendor
        $firstWord = Get-FirstWordCandidate -Text $description
        if ($firstWord -and ($ValidVendors -contains $firstWord)) {
            Write-Host "Successfully derived vendor '$firstWord' from description."
            $vendor.Value = $firstWord
            $logEntry = "Vendor set for AAGUID '$aaguid': '' to '$firstWord' (derived from description)."
            [void]$detailedLogContent.Add($logEntry)
            Write-Host "Added log entry for vendor derivation: $logEntry"
            $changesDetected.Value = $true
            [void]$currentLogEntries.Add($logEntry)
            return "Yes"
        }

        # Try to find any valid vendor in the description
        $found = Find-VendorInDescription -Text $description -Vendors $ValidVendors
        if ($found) {
            Write-Host "Found valid vendor '$found' in description for AAGUID '$aaguid'."
            $vendor.Value = $found
            $logEntry = "Vendor derived for AAGUID '$aaguid': '' to '$found' from description match."
            [void]$detailedLogContent.Add($logEntry)
            Write-Host "Added log entry for vendor derivation: $logEntry"
            $changesDetected.Value = $true
            [void]$currentLogEntries.Add($logEntry)
            return "Yes"
        }

        # If we couldn't derive a valid vendor, log the error and continue with validation failure
        $logEntry = "Failed to derive valid vendor for AAGUID '$aaguid' with description '$description'. Vendor field was empty."
        [void]$detailedLogContent.Add($logEntry)
        Write-Host $logEntry
        [void]$currentLogEntries.Add($logEntry)
        $changesDetected.Value = $true

        # Prepare issue entry
        if ($IsNewEntry) {
            $logEntryTrimmed = $logEntry.Trim()
            if (-not ($existingLogEntries -contains $logEntryTrimmed)) {
                [void]$markdownContent.Add($logEntry)
                $issueTitle = "Empty Vendor Detected for AAGUID $aaguid"
                $issueBody = $logEntry
                $issueKey = "$issueTitle|$issueBody|InvalidVendor"
                # Check if this issue is already in the list
                if (-not ($issueEntries -contains $issueKey)) {
                    [void]$issueEntries.Add($issueKey)
                }
            }
        }
        return "No"
    }

    # Check if the vendor is valid
    if ($ValidVendors -contains $vendor.Value) {
        return "Yes"
    }

    # Attempt to use the first word of the description as the vendor
    $firstWord = Get-FirstWordCandidate -Text $description
    if ($firstWord -and $firstWord -ne $vendor.Value) {
        Write-Host "Vendor '$($vendor.Value)' is invalid. Trying first word of description '$firstWord' as vendor."
        if ($ValidVendors -contains $firstWord) {
            Write-Host "Vendor '$firstWord' is valid."
            $oldVendor = $vendor.Value
            $vendor.Value = $firstWord
            $logEntry = "Vendor corrected for AAGUID '$aaguid': '$oldVendor' to '$firstWord'."
            [void]$detailedLogContent.Add("")
            [void]$detailedLogContent.Add($logEntry)
            Write-Host "Added log entry for vendor correction: $logEntry"
            $changesDetected.Value = $true
            [void]$currentLogEntries.Add($logEntry)
            return "Yes"
        }
    }

    # Try to find any valid vendor in the description
    $found = Find-VendorInDescription -Text $description -Vendors $ValidVendors
    if ($found) {
        Write-Host "Found valid vendor '$found' in description for AAGUID '$aaguid'."
        $oldVendor = $vendor.Value
        $vendor.Value = $found
        $logEntry = "Vendor updated for AAGUID '$aaguid': '$oldVendor' to '$found' from description match."
        [void]$detailedLogContent.Add("")
        [void]$detailedLogContent.Add($logEntry)
        Write-Host "Added log entry for vendor correction: $logEntry"
        $changesDetected.Value = $true
        [void]$currentLogEntries.Add($logEntry)
        return "Yes"
    }

    # Log invalid vendor for the specific key if it's a new entry
    if ($IsNewEntry) {
        $logEntry = "Invalid vendor detected for AAGUID '$aaguid' with description '$description'. Vendor '$($vendor.Value)' is not in the list of valid vendors."
        $logEntryTrimmed = $logEntry.Trim()

        if (-not ($existingLogEntries -contains $logEntryTrimmed)) {
            [void]$markdownContent.Add($logEntry)
            [void]$detailedLogContent.Add("")
            [void]$detailedLogContent.Add($logEntry)
            Write-Host "Added log entry for invalid vendor: $logEntry"
            [void]$currentLogEntries.Add($logEntry)
            $changesDetected.Value = $true

            # Prepare issue entry with AAGUID included in the title
            $issueTitle = "Invalid Vendor Detected for AAGUID $aaguid : $($vendor.Value)"
            $issueBody = $logEntry
            $issueKey = "$issueTitle|$issueBody|InvalidVendor"
            # Check if this issue is already in the list
            if (-not ($issueEntries -contains $issueKey)) {
                [void]$issueEntries.Add($issueKey)
            }
        }
    }
    return "No"
}
