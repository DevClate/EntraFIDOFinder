<#
.SYNOPSIS
    Tests if a given AAGUID exists in a list of keys.

.DESCRIPTION
    This function checks if a specified AAGUID is present in an array of keys. 
    It iterates through each key and compares its AAGUID property with the provided AAGUID.

.PARAMETER aaguid
    The AAGUID to search for in the keys array.

.PARAMETER keys
    An array of keys, each containing an AAGUID property.

.RETURNS
    [bool] $true if the AAGUID is found in the keys array, otherwise $false.

.EXAMPLE
    $keys = @(
        @{ AAGUID = "1234" },
        @{ AAGUID = "5678" }
    )
    Test-GHAAGUIDExists -aaguid "1234" -keys $keys
    # Returns: $true

.EXAMPLE
    $keys = @(
        @{ AAGUID = "1234" },
        @{ AAGUID = "5678" }
    )
    Test-GHAAGUIDExists -aaguid "9999" -keys $keys
    # Returns: $false
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