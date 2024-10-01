<#
.SYNOPSIS
    Finds FIDO keys based on specified criteria.

.DESCRIPTION
    The Find-FIDOKey function filters and displays FIDO keys from a JSON file based on specified Brand, Type, View, and TypeFilterMode parameters. 
    It supports filtering by multiple types, and allows the results to be displayed in either a table or list format.

.PARAMETER Brand
    Specifies the brand of FIDO keys to filter by.

.PARAMETER Type
    Specifies the type(s) of FIDO keys to filter by. Accepts multiple values from a predefined set of types: Bio, USB, NFC, BLE.

.PARAMETER View
    Specifies the format in which to display the results. Accepts either "Table" or "List". Default is "List".

.PARAMETER TypeFilterMode
    Specifies the mode for filtering by type. Accepts one of the following values:
    - AtLeastTwo: At least two of the specified types must match.
    - AtLeastOne: At least one of the specified types must match. (Default)
    - AtLeastThree: At least three of the specified types must match.
    - All: All specified types must match.

.EXAMPLE
    Find-FIDOKey -Brand "Yubico" -Type "USB" -View "Table"
    Finds and displays all Yubico FIDO keys that support USB in a table format.

.EXAMPLE
    Find-FIDOKey -Type "Bio", "NFC" -TypeFilterMode "AtLeastTwo"
    Finds and displays all FIDO keys that support at least Bio and NFC.

.NOTES
    The function reads FIDO key data from a JSON file located at "../Assets/FidoKeys.json".
#>
function Find-FIDOKey {
    [CmdletBinding()]
    param (
        # Parameter for filtering by Brand
        [Parameter()]
        [ValidateSet("ACS","Allthenticator","Arculus","AuthenTrend","Atos","authenton1","Chunghwa Telecom",
            "Crayonic","Cryptnox","Egomet","Ensurity","eWBM","Excelsecu","Feitian","FIDO KeyPass","FT-JCOS",
            "Google","GoTrust","HID Global","Hideez","Hypersecu","HYPR","IDCore","IDEMIA","IDmelon","Thales",
            "ImproveID","KEY-ID","KeyXentic","KONAI","NEOWAVE","NXP Semiconductors","Nymi","OCTATCO","OneSpan",
            "OnlyKey","OpenSK","Pone Biometrics","Precision","RSA","SafeNet","Yubico","Sentry Enterprises",
            "SmartDisplayer","SoloKeys","Swissbit","Taglio","Token Ring","TOKEN2","Identiv","VALMIDO","Kensington",
            "VinCSS","WiSECURE")]
        [string[]]$Brand,

        # Parameter for filtering by Type (Bio, USB, NFC, BLE)
        [Parameter()]
        [ValidateSet("Bio", "USB", "NFC", "BLE")]
        [string[]]$Type,

        # Parameter for specifying the view format (Table or List)
        [Parameter()]
        [ValidateSet("Table", "List")]
        [string]$View = "List",

        # Parameter for specifying the type filter mode (AtLeastTwo, AtLeastOne, AtLeastThree, All)
        [Parameter()]
        [ValidateSet("AtLeastTwo", "AtLeastOne", "AtLeastThree", "All")]
        [string]$TypeFilterMode = "AtLeastOne"
    )
    
    # Start with all devices
    $results = Get-Content -raw "$PSScriptRoot/../Assets/FidoKeys.json" | ConvertFrom-Json

    
    # Filter by Brand if provided
    if ($Brand) {
        $results = $results | Where-Object {
            $Brand -contains $_.Vendor -or ($Brand | ForEach-Object { $_ -in $_.Description })
        }
    }

    # Filter by Type if provided
    if ($Type) {
        $results = $results | Where-Object {
            $typeCount = 0
            if ($Type -contains "Bio" -and $_.Bio -eq "Yes") { $typeCount++ }
            if ($Type -contains "USB" -and $_.USB -eq "Yes") { $typeCount++ }
            if ($Type -contains "NFC" -and $_.NFC -eq "Yes") { $typeCount++ }
            if ($Type -contains "BLE" -and $_.BLE -eq "Yes") { $typeCount++ }

            switch ($TypeFilterMode) {
                "AtLeastTwo" { $typeCount -ge 2 }
                "AtLeastThree" { $typeCount -ge 3 }
                "All" { $typeCount -eq $Type.Count }
                default { $typeCount -ge 1 }
            }
        }
    }

    # Output results based on the specified view format
    if ($results.Count -gt 0) {
        Write-Host "FIDO Devices eligible for attestation with Entra ID: $($results.Count)"
        if ($View -eq "Table") {
            $results | Format-Table -AutoSize
        }
        else {
            $results
        }
    }
    else {
        Write-Host "No devices found matching the criteria."
    }
}