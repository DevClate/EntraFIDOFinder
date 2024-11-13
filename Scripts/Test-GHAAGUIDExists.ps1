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