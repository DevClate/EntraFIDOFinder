<#
.SYNOPSIS
    Finds and filters FIDO keys based on specified criteria.

.DESCRIPTION
    This function loads FIDO key data from a JSON file and filters the keys based on the provided parameters such as Brand, Type, FIDO Version, and Type Filter Mode. The results can be displayed in either Table or List format.

.PARAMETER Brand
    Specifies the brand(s) of the FIDO keys to filter. Accepts multiple values.

.PARAMETER Type
    Specifies the type(s) of the FIDO keys to filter (Bio, USB, NFC, BLE). Accepts multiple values.

.PARAMETER View
    Specifies the format of the output view. Can be either 'Table' or 'List'. Default is 'List'.

.PARAMETER TypeFilterMode
    Specifies the mode for filtering by Type. Can be 'AtLeastTwo', 'AtLeastOne', 'AtLeastThree', or 'All'. Default is 'AtLeastOne'.

.PARAMETER FIDOVersion
    Specifies the FIDO version to filter the keys by.

.PARAMETER AllProperties
    Switch to include all properties in the output.

.EXAMPLE
    Find-FIDOKey -Brand "Yubico" -Type "USB" -View "Table"

    Finds and displays all Yubico FIDO keys that support USB in a table format.

.EXAMPLE
    Find-FIDOKey -Type "Bio", "NFC" -TypeFilterMode "AtLeastTwo"

    Finds and displays all FIDO keys that support at least Bio and NFC.

.NOTES
    The function expects a JSON file named 'FidoKeys.json' in the 'Assets' directory located two levels up from the script's directory.

#>
function Find-FIDOKey {
    [CmdletBinding()]
    param (
        # Parameter for filtering by Brand
        [Parameter()]
        [ValidateSet("ACS", "Allthenticator", "Arculus", "AuthenTrend", "Atos", "authenton1", "Chunghwa Telecom",
            "Crayonic", "Cryptnox", "Egomet", "Ensurity", "eWBM", "Excelsecu", "Feitian", "FIDO KeyPass", "FT-JCOS",
            "Google", "GoTrust", "HID Global", "Hideez", "Hypersecu", "HYPR", "IDCore", "IDEMIA", "IDmelon", "Thales",
            "ImproveID", "KEY-ID", "KeyXentic", "KONAI", "NEOWAVE", "NXP Semiconductors", "Nymi", "OCTATCO", "OneSpan",
            "OnlyKey", "OpenSK", "Pone Biometrics", "Precision", "RSA", "SafeNet", "Yubico", "Sentry Enterprises",
            "SmartDisplayer", "SoloKeys", "Swissbit", "Taglio", "Token Ring", "TOKEN2", "Identiv", "VALMIDO", "Kensington",
            "VinCSS", "WiSECURE")]
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
        [string]$TypeFilterMode = "AtLeastOne",

        # Parameter for filtering by FIDO Version
        [Parameter()]
        [ValidateSet("FIDO U2F", "FIDO 2.0", "FIDO 2.1", "FIDO 2.1 PRE")]
        [string]$FIDOVersion,

        # Switch to include all properties in the output
        [Parameter()]
        [switch]$AllProperties
    )

    # Construct the path to the JSON file
    $parentDir = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $JsonFilePath = Join-Path -Path $parentDir -ChildPath "Assets/FidoKeys.json"
    
    # Check if the file exists
    if (-not (Test-Path -Path $jsonFilePath)) {
        Write-Error "The JSON file was not found at path: $jsonFilePath"
        return
    }

    # Load the data
    $data = Get-Content -Raw $jsonFilePath | ConvertFrom-Json -AsHashtable
    $results = $data.keys

    # Filter by Brand if provided
    if ($Brand) {
        $results = $results | Where-Object {
            $Brand -contains $_.Vendor
        }
    }

    # Filter by FIDO Version if provided
    if ($FIDOVersion) {
        $results = $results | Where-Object {
            $_.Version -eq $FIDOVersion
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

    # Sort the results by Vendor in alphabetical order
    $results = $results | Sort-Object -Property Vendor

    # Helper function to convert nested hashtables to JSON strings recursively
    function Convert-HashtableToJson {
        param ([PSCustomObject]$Object)
        foreach ($property in $Object.PSObject.Properties) {
            if ($property.Value -is [System.Collections.Hashtable]) {
                $Object | Add-Member -MemberType NoteProperty -Name $property.Name -Value ($property.Value | ConvertTo-Json -Compress -Depth 10) -Force
            }
            elseif ($property.Value -is [System.Collections.IEnumerable] -and -not ($property.Value -is [string])) {
                $Object | Add-Member -MemberType NoteProperty -Name $property.Name -Value ($property.Value | ForEach-Object { if ($_ -is [System.Collections.Hashtable]) { $_ | ConvertTo-Json -Compress -Depth 10 } else { $_ } }) -Force
            }
        }
        return $Object
    }

    # Build a PSCustomObject for each device
    function Build-CustomObject {
        param ([PSCustomObject]$Device)
        $customObject = [PSCustomObject]@{
            Vendor                 = $Device.Vendor
            Description            = $Device.Description
            AAGUID                 = $Device.AAGUID
            Bio                    = $Device.Bio
            USB                    = $Device.USB
            NFC                    = $Device.NFC
            BLE                    = $Device.BLE
            Version                = $Device.Version
            ValidVendor            = $Device.ValidVendor
            TimeOfLastStatusChange = $Device.timeOfLastStatusChange
            # Going to add more properties here
        }
        return $customObject
    }

    # Output results based on the specified view format
    if ($results.Count -gt 0) {
        if ($AllProperties) {
            # Convert nested hashtables to JSON strings and build custom objects
            $output = $results | ForEach-Object {
                $converted = Convert-HashtableToJson -Object $_
                Build-CustomObject -Device $converted
            }
        }
        else {
            $output = $results | Select-Object Vendor, Description, AAGUID, Bio, USB, NFC, BLE, Version, ValidVendor
        }

        if ($View -eq "Table") {
            $output | Format-Table -AutoSize
        }
        else {
            $output | Format-List -Property * -Force
        }
    }
    else {
        Write-Warning "No FIDO devices found matching the specified criteria."
    }
}