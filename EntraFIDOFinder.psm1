# EntraFIDOFinder.psm1

function Get-FidoKeys {
    $jsonPath = "$PSScriptRoot/../Assets/FidoKeys.json"
    if (Test-Path $jsonPath) {
        return Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
    } else {
        throw "FidoKeys.json file not found at $jsonPath"
    }
}

$FunctionFiles = $("$PSScriptRoot\Functions\Public\","$PSScriptRoot\Functions\Private\") | Get-ChildItem -File -Recurse -Include "*.ps1" -ErrorAction SilentlyContinue

foreach ($FunctionFile in $FunctionFiles) {
    try {
        . $FunctionFile.FullName
    } catch {
        Write-Error -Message "Failed to import function: '$($FunctionFile.FullName)': $_"
    }
}

# Export the Get-FidoKeys function
Export-ModuleMember -Function Get-FidoKeys

# Export other functions
Export-ModuleMember -Function $FunctionFiles.BaseName