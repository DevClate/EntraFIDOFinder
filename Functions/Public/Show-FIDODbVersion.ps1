<#
.SYNOPSIS
Displays the last updated date of the FIDO database from a specified JSON file and checks if it is the most current version.

.DESCRIPTION
The Show-FIDODbVersion function retrieves and displays the last updated date of the FIDO database from a JSON file.
The JSON file can be specified by a file path. If no file path is provided, the function attempts to locate the JSON file in a default directory.
The function also downloads the latest version of the JSON file from a predefined URL and compares the dates to inform the user if their local version is the most current.

.PARAMETER JsonFilePath
Specifies the path to the JSON file containing the FIDO database metadata. This parameter is optional.

.EXAMPLE
Show-FIDODbVersion -JsonFilePath "C:\Path\To\FidoKeys.json"
Displays the last updated date of the FIDO database from the specified JSON file and checks if it is the most current version.

.EXAMPLE
Show-FIDODbVersion
Attempts to locate the JSON file in a default directory, displays the last updated date of the FIDO database, and checks if it is the most current version.

.NOTES
If the JsonFilePath parameter is omitted, the function attempts to locate the JSON file in a default directory relative to the script's location.

#>

function Show-FIDODbVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$JsonFilePath
    )

    # Default URL for the latest JSON file
    $latestJsonUrl = "https://raw.githubusercontent.com/DevClate/EntraFIDOFinder/main/Assets/FidoKeys.json"

    # Determine the JSON file path
    if (-not $JsonFilePath) {
        $parentDir = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $JsonFilePath = Join-Path -Path $parentDir -ChildPath "Assets/FidoKeys.json"
    }

    # Check if the local JSON file exists
    if (-Not (Test-Path -Path $JsonFilePath)) {
        Write-Error "The JSON file was not found at path: $JsonFilePath"
        return
    }

    # Read the local JSON file
    $localJsonData = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json

    # Check if the metadata and databaseLastUpdated fields exist in the local JSON file
    if ($null -eq $localJsonData.metadata -or $null -eq $localJsonData.metadata.databaseLastUpdated) {
        Write-Error "The local JSON file does not contain the required metadata or databaseLastUpdated fields."
        return
    }

    # Display the last updated date of the local JSON file
    $localLastUpdated = $localJsonData.metadata.databaseLastUpdated
    Write-Output "The local database was last updated on: $localLastUpdated"

    # Fetch the latest JSON file from the URL
    try {
        $latestJsonData = Invoke-RestMethod -Uri $latestJsonUrl
    } catch {
        Write-Error "Failed to download the latest JSON file from URL: $latestJsonUrl"
        return
    }

    # Check if the metadata and databaseLastUpdated fields exist in the latest JSON file
    if ($null -eq $latestJsonData.metadata -or $null -eq $latestJsonData.metadata.databaseLastUpdated) {
        Write-Error "The latest JSON file does not contain the required metadata or databaseLastUpdated fields."
        return
    }

    # Get the last updated date of the latest JSON file
    $latestLastUpdated = $latestJsonData.metadata.databaseLastUpdated

    # Compare the dates and inform the user
    if ($localLastUpdated -eq $latestLastUpdated) {
        Write-Output "Your local database is up to date."
    } else {
        Write-Output "A newer version of the database is available. The latest database was last updated on: $latestLastUpdated"
    }
}