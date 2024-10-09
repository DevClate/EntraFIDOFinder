<#
.SYNOPSIS
Displays the last updated date of the FIDO database from a specified JSON file.

.DESCRIPTION
The Show-FIDODbVersion function retrieves and displays the last updated date of the FIDO database from a JSON file. 
The JSON file can be specified by a file path or URL. If no file path is provided, the function attempts to locate 
the JSON file in a default directory. The function can also download the latest version of the JSON file from a 
specified URL.

.PARAMETER JsonFilePath
Specifies the path to the JSON file containing the FIDO database metadata. This parameter is optional.

.PARAMETER NewestVersion
If specified, the function will download the latest version of the JSON file from a predefined URL. This parameter 
is optional.

.EXAMPLE
Show-FIDODbVersion -JsonFilePath "C:\Path\To\FidoKeys.json"
Displays the last updated date of the FIDO database from the specified JSON file.

.EXAMPLE
Show-FIDODbVersion -NewestVersion
Downloads the latest version of the JSON file from the predefined URL and displays the last updated date of the 
FIDO database.

.NOTES
If both parameters are omitted, the function attempts to locate the JSON file in a default directory relative to 
the script's location.

#>

function Show-FIDODbVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$JsonFilePath,
        
        [Parameter(Mandatory = $false)]
        [switch]$NewestVersion
    )

    # Determine the JSON file path or URL
    if ($NewestVersion) {
        $JsonFilePath = "https://raw.githubusercontent.com/DevClate/EntraFIDOFinder/main/Assets/FidoKeys.json"
    } elseif (-not $JsonFilePath) {
        $parentDir = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $JsonFilePath = Join-Path -Path $parentDir -ChildPath "Assets/FidoKeys.json"
    }

    # Check if the JSON file exists or download it if it's a URL
    if ($JsonFilePath -match "^https?://") {
        try {
            $jsonData = Invoke-RestMethod -Uri $JsonFilePath
        } catch {
            Write-Error "Failed to download the JSON file from URL: $JsonFilePath"
            return
        }
    } else {
        if (-Not (Test-Path -Path $JsonFilePath)) {
            Write-Error "The JSON file was not found at path: $JsonFilePath"
            return
        }
        $jsonData = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
    }

    # Check if the metadata and databaseLastUpdated fields exist
    if ($null -eq $jsonData.metadata -or $null -eq $jsonData.metadata.databaseLastUpdated) {
        Write-Error "The JSON file does not contain the required metadata or databaseLastUpdated fields."
        return
    }

    # Display the last updated date
    $lastUpdated = $jsonData.metadata.databaseLastUpdated
    Write-Output "The database was last updated on: $lastUpdated"
}
