<#
.SYNOPSIS
    Find FIDO keys eligible for attestation with Entra ID.
.DESCRIPTION
    This function retrieves FIDO keys from a JSON file and filters them based on the provided criteria.
    The function supports filtering by Brand, Type (Bio, USB, NFC, BLE), AAGUID, TypeFilterMode, and AllProperties.
    The results can be displayed in a table or list format.
.PARAMETER Brand
    Filter the FIDO keys by Brand. The available brands are listed in the ValidateSet.
.PARAMETER Type
    Filter the FIDO keys by Type. The available types are Bio, USB, NFC, and BLE.
.PARAMETER AAGUID
    Filter the FIDO keys by AAGUID. The AAGUIDs can be provided as an array of strings.
.PARAMETER AAGUIDFile
    Filter the FIDO keys by AAGUIDs imported from a file. Supported file formats are .txt, .csv, and .xlsx.
.PARAMETER View
    Specify the view format for the results. The available options are Table and List
.PARAMETER TypeFilterMode
    Specify the type filter mode. The available options are AtLeastTwo, AtLeastOne, AtLeastThree, and All.
.PARAMETER AllProperties
    Include all properties of the FIDO keys in the output as Json.
.PARAMETER DetailedProperties
    Include detailed properties of the FIDO keys in the output.
.EXAMPLE
    Find-FIDOKey -Brand "Yubico" -Type "USB" -View "Table"
    Find FIDO keys from the Yubico brand that support USB and display the results in a table format.
.EXAMPLE
    Find-FIDOKey -AAGUID "12345678" -View "List"
    Find FIDO keys with the specified AAGUID and display the results in a list format.
.EXAMPLE    
    Find-FIDOKey -AAGUIDFile "AAGUIDs.txt" -View "Table"
    Find FIDO keys with AAGUIDs imported from a text file and display the results in a table format.
.EXAMPLE
    Find-FIDOKey -DetailedProperties | Select-Object Vendor, Description, @{Name="ProtocolFamily";Expression={$_.metadataStatement.protocolFamily}} | fl
    Find FIDO keys and show the standard properties  with version from FIDO Alliance metadata.
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

        [Parameter(
            Position = 0,
            ValueFromPipeline = $true
        )]
        [string[]]$AAGUID,

        [Parameter()]
        [string[]]$AAGUIDFile,

        # Parameter for specifying the view format (Table or List)
        [Parameter()]
        [ValidateSet("Table", "List")]
        [string]$View,

        # Parameter for specifying the type filter mode (AtLeastTwo, AtLeastOne, AtLeastThree, All)
        [Parameter()]
        [ValidateSet("AtLeastTwo", "AtLeastOne", "AtLeastThree", "All")]
        [string]$TypeFilterMode = "AtLeastOne",

        [parameter()]
        [switch]$AllProperties,

        [Parameter()]
        [switch]$DetailedProperties
    )


    # Begin block for initialization
    Begin {
        # Initialize an array to collect all AAGUIDs
        $allAAGUIDs = @()

<#
        # Ensure ImportExcel module is installed for .xlsx support
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Install-Module -Name ImportExcel -Force -Scope CurrentUser
        }

        # Import the module
        Import-Module ImportExcel -ErrorAction Stop
#> 
    }


    # Process block to handle pipeline input
    Process {
        # Collect the pipeline input AAGUIDs
        if ($AAGUID) {
            $allAAGUIDs += $AAGUID
        }
    }

    # End block for processing and output
    End {
        # Include AAGUIDs provided via the -AAGUID parameter
        if ($PSBoundParameters.ContainsKey('AAGUID')) {
            $allAAGUIDs += $PSBoundParameters['AAGUID']
        }

        # If AAGUIDFile is provided, import the AAGUIDs from the file
         if ($AAGUIDFile) {
            if (-Not (Test-Path -Path $AAGUIDFile)) {
                Write-Error "The AAGUID file was not found at path: $AAGUIDFile"
                return
            }
            else {
                $extension = [IO.Path]::GetExtension($AAGUIDFile).ToLowerInvariant()
                switch ($extension) {
                    '.txt' {
                        $fileContent = Get-Content -Path $AAGUIDFile
                    }
                    '.csv' {
                        $fileContent = Import-Csv -Path $AAGUIDFile | Select-Object -ExpandProperty AAGUID
                    }
                    '.xlsx' {
                        # Check if ImportExcel module is installed
                        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
                            Write-Host "The 'ImportExcel' module is required to import .xlsx files."
                            Write-Host "Please install it by running 'Install-PSResource -Name ImportExcel -Scope CurrentUser'"
                            return
                        }
                        else {
                            # Import the module
                            Import-Module ImportExcel -ErrorAction Stop
                            # Import data from the .xlsx file
                            $fileContent = Import-Excel -Path $AAGUIDFile | Select-Object -ExpandProperty AAGUID
                        }
                    }
                    default {
                        Write-Error "Unsupported file extension: $extension. Supported extensions are .txt, .csv, .xlsx."
                        return
                    }
                }

                $fileAAGUIDs = $fileContent | Where-Object { -Not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }

                # Combine AAGUIDs from file with any existing AAGUIDs
                $allAAGUIDs += $fileAAGUIDs
            }
        }

        # Remove duplicate AAGUIDs if any
        $allAAGUIDs = $allAAGUIDs | Select-Object -Unique

        # Load existing FIDO keys from JSON file
        $parentDir = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $jsonFilePath = Join-Path -Path $parentDir -ChildPath "Assets/FidoKeys.json"

        if (-Not (Test-Path -Path $jsonFilePath)) {
            Write-Error "The JSON file was not found at path: $jsonFilePath"
            return
        }

        $data = Get-Content -Raw $jsonFilePath | ConvertFrom-Json
        $metadata = $data.metadata
        $results = $data.keys

        # Filter by AAGUID if provided
        if ($allAAGUIDs) {
            $results = $results | Where-Object {
                $allAAGUIDs -contains $_.AAGUID
            }
        }
        
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

        # Sort the results by Vendor in alphabetical order
       $results = $results | Sort-Object -Property Vendor

        if ($View) {
            if ($results.Count -gt 0) {
                Write-Host "FIDO Devices eligible for attestation with Entra ID: $($results.Count)"
                Write-Host "Database Last Updated: $($metadata.databaseLastUpdated)"
                if ($View -eq "Table") {
                    if ($DetailedProperties -or $FormattedProperties) {
                        # Directly output the results
                        $results | Format-Table -AutoSize
                    } elseif ($AllProperties) {
                        $results | ConvertTo-Json -Depth 10 | Out-String | Write-Host
                    } else {
                        $results | Format-Table -Property Vendor, Description, AAGUID, Bio, USB, NFC, BLE, Version, ValidVendor -AutoSize
                    }
                } else {
                    if ($DetailedProperties) {
                        # Directly output the results
                        $results | Format-List
                    } elseif ($AllProperties) {
                        $results | ConvertTo-Json -Depth 10 | Out-String | Write-Host
                    } else {
                        $results | Select-Object Vendor, Description, AAGUID, Bio, USB, NFC, BLE, Version, ValidVendor
                    }
                }
            } else {
                Write-Host "No devices found matching the criteria."
            }
        } else {
            if ($DetailedProperties) {
                # Return the results directly
                return $results
            } elseif ($AllProperties) {
                return $results | ConvertTo-Json -Depth 10
            } else {
                return $results | Select-Object Vendor, Description, AAGUID, Bio, USB, NFC, BLE, Version, ValidVendor
            }
        }
    }
}
