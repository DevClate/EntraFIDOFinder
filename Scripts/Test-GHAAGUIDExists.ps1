<#
.SYNOPSIS
    Checks if a given AAGUID exists in a list of FIDO keys.

.DESCRIPTION
    The `Test-GHAAGUIDExists` function iterates through a list of FIDO keys and checks if any key has the specified AAGUID. If a match is found, the function returns `$true`; otherwise, it returns `$false`.

.PARAMETER aaguid
    The AAGUID to check for in the list of FIDO keys.

.PARAMETER keys
    The list of FIDO keys to search through. Each key should be an object with an `AAGUID` property.

.EXAMPLE
    $aaguid = "12345678-1234-1234-1234-123456789012"
    $keys = @(
        @{ AAGUID = "12345678-1234-1234-1234-123456789012" },
        @{ AAGUID = "87654321-4321-4321-4321-210987654321" }
    )
    $exists = Test-GHAAGUIDExists -aaguid $aaguid -keys $keys
    if ($exists) {
        Write-Host "AAGUID exists in the list."
    } else {
        Write-Host "AAGUID does not exist in the list."
    }

.NOTES
    This function is useful for validating the presence of a specific AAGUID in a collection of FIDO keys.
#>
function Test-GHAAGUIDExists {
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