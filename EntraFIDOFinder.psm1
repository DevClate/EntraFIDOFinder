$FunctionFiles = $("$PSScriptRoot\Functions\Public\","$PSScriptRoot\Functions\Private\") | Get-ChildItem -File -Recurse -Include "*.ps1" -ErrorAction SilentlyContinue

foreach ($FunctionFile in $FunctionFiles) {
    try {
        . $FunctionFile.FullName
    } catch {
        Write-Error -Message "Failed to import function: '$($FunctionFile.FullName)': $_"
    }
}

# Export other functions
Export-ModuleMember -Function $FunctionFiles.BaseName