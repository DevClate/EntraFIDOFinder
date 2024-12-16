# Load existing FIDO keys from local JSON file
$existingKeyFile = "Assets/FIDOCTKeys.json"
$existingFIDOKeys = Get-Content $existingKeyFile -Raw | ConvertFrom-Json -Depth 10

# Fetch FIDO Alliance keys from the MDS3 endpoint
$FIDOUri = "https://mds3.fidoalliance.org/"
$FIDOAURL = Invoke-WebRequest -Uri $FIDOUri
$FIDOAKeys = $FIDOAURL | Get-JWTDetails

# Initialize the log buffer as an ArrayList
$LogBuffer = New-Object System.Collections.ArrayList

# Define the log file path
$LogFilePath = "FAMergeLog.txt"

# Initialize the changes tracking variable
$ChangesMade = $false

# Create a list of common AAGUIDs between existing keys and FIDO Alliance keys
$CommonAAGUIDs = @($existingFIDOKeys.keys.AAGUID) | Where-Object {
    $FIDOAKeys.entries.aaguid -contains $_
}

# Function to get a timestamp for logging
function Get-Timestamp {
    return (Get-Date -AsUTC).ToString("yyyy-MM-dd HH:mm:ss")
}

# Function to add log entries to the log buffer
function Add-ToLogBuffer {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    $script:LogBuffer.Add($Value) | Out-Null
}

# Function to normalize 'versions' property
function Normalize-Versions {
    param ([PSCustomObject]$metadataStatement)
    
    if ($metadataStatement.authenticatorGetInfo) {
        $versions = $metadataStatement.authenticatorGetInfo.versions
        if ($versions) {
            $normalizedVersions = $versions | ForEach-Object {
                $_ -replace '([0-9])_([0-9])', '$1.$2' -replace '_', ' '
            }
            $metadataStatement.authenticatorGetInfo.versions = $normalizedVersions
        }
    }
    return $metadataStatement
}

# Function to ensure that specified properties are always arrays
function Ensure-ArrayProperty {
    param (
        [Parameter(Mandatory = $true)]
        [psobject]$Object,
        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    foreach ($property in $Object.PSObject.Properties) {
        $value = $property.Value
        if ($PropertyNames -contains $property.Name) {
            if ($value -isnot [System.Collections.IEnumerable] -or $value -is [string]) {
                # Wrap the value in an array
                $Object.$($property.Name) = @($value)
            }
        } elseif ($value -is [PSCustomObject]) {
            Ensure-ArrayProperty -Object $value -PropertyNames $PropertyNames
        } elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            foreach ($item in $value) {
                if ($item -is [PSCustomObject]) {
                    Ensure-ArrayProperty -Object $item -PropertyNames $PropertyNames
                }
            }
        }
    }
}

# Function to compare two objects and update differences
function Compare-Objects {
    param (
        [ref]$obj1,
        [ref]$obj2,
        $path = '',
        [switch]$update,
        $AAGUID
    )

    # Exclude automatic properties
    $excludedProperties = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'ReadCount', 'Length', 'Count')
    # Get properties that are part of the original JSON data
    $jsonProperties = $obj1.Value.PSObject.Properties | Where-Object {
        $_.MemberType -eq 'NoteProperty' -and
        ($excludedProperties -notcontains $_.Name)
    }

    foreach ($prop in $jsonProperties) {
        $name = $prop.Name
        $value1 = $prop.Value
        $value2 = $obj2.Value.PSObject.Properties[$name]?.Value
        $currentPath = if ($path) { "$path.$name" } else { $name }

        if ($value1 -is [PSCustomObject] -or $value1 -is [Array]) {
            if ($value1 -is [Array] -and $value2 -is [Array]) {
                if ($value1.Count -ne $value2.Count) {
                    if ($update) {
                        $timestamp = Get-Timestamp
                        $value1Str = $value1 | ConvertTo-Json -Depth 100
                        $value2Str = $value2 | ConvertTo-Json -Depth 100
                        $logMessage = @"
$timestamp - AAGUID: $AAGUID
Path: $currentPath
Old Value:
$value1Str

New Value:
$value2Str

"@
                        Write-Output $logMessage
                        Add-ToLogBuffer -Value $logMessage
                        # Set the changes made flag to true
                        $script:ChangesMade = $true
                        # Update the value
                        if ($prop.IsSettable) {
                            $obj1.Value.$name = $value2
                        }
                    }
                } else {
                    for ($i = 0; $i -lt $value1.Count; $i++) {
                        $item1 = $value1[$i]
                        $item2 = $value2[$i]
                        Compare-Objects -obj1 ([ref]$item1) -obj2 ([ref]$item2) -path "$currentPath`[$i`]" -update:$update -AAGUID $AAGUID
                    }
                }
            } else {
                Compare-Objects -obj1 ([ref]$value1) -obj2 ([ref]$value2) -path $currentPath -update:$update -AAGUID $AAGUID
            }
        } else {
            if ($value1 -ne $value2) {
                if ($update) {
                    $timestamp = Get-Timestamp
                    $value1Str = try { $value1 | ConvertTo-Json -Depth 100 } catch { $value1.ToString() }
                    $value2Str = try { $value2 | ConvertTo-Json -Depth 100 } catch { $value2.ToString() }
                    $logMessage = "$timestamp - Updating AAGUID $AAGUID : $currentPath : $value1Str -> $value2Str"
                    Write-Output $logMessage
                    Add-ToLogBuffer -Value $logMessage
                    # Set the changes made flag to true
                    $script:ChangesMade = $true
                    # Update the value
                    if ($prop.IsSettable) {
                        $obj1.Value.$name = $value2
                    }
                }
            }
        }
    }
}

# Main comparison and update loop
foreach ($AAGUID in $CommonAAGUIDs) {
    # Get the entries with the current AAGUID
    $EXXXKey = $existingFIDOKeys.keys | Where-Object { $_.AAGUID -eq $AAGUID }
    $FAAAKey = $FIDOAKeys.entries | Where-Object { $_.aaguid -eq $AAGUID }

    if ($EXXXKey -and $FAAAKey) {
        # Update timeOfLastStatusChange if different
        if ($EXXXKey.timeOfLastStatusChange -ne $FAAAKey.timeOfLastStatusChange) {
            $timestamp = Get-Timestamp
            $logMessage = @"
$timestamp - AAGUID: $AAGUID
Updating timeOfLastStatusChange
Old Value:
$($EXXXKey.timeOfLastStatusChange)

New Value:
$($FAAAKey.timeOfLastStatusChange)

"@
            Write-Output $logMessage
            Add-ToLogBuffer -Value $logMessage
            $EXXXKey.timeOfLastStatusChange = $FAAAKey.timeOfLastStatusChange
            # Set the changes made flag to true
            $script:ChangesMade = $true
        }

        # Normalize versions
        $EXXXKey.metadataStatement = Normalize-Versions $EXXXKey.metadataStatement
        $FAAAKey.metadataStatement = Normalize-Versions $FAAAKey.metadataStatement

        # Compare and update metadataStatement
        Compare-Objects -obj1 ([ref]$EXXXKey.metadataStatement) -obj2 ([ref]$FAAAKey.metadataStatement) -update -AAGUID $AAGUID

        # Compare and update statusReports
        if ($EXXXKey.statusReports -and $FAAAKey.statusReports) {
            Compare-Objects -obj1 ([ref]$EXXXKey.statusReports) -obj2 ([ref]$FAAAKey.statusReports) -path 'statusReports' -update -AAGUID $AAGUID
        }
    }
}

# Enforce that 'versions' properties are always arrays
foreach ($key in $existingFIDOKeys.keys) {
    if ($key.metadataStatement) {
        Ensure-ArrayProperty -Object $key.metadataStatement -PropertyNames 'versions'
    }
}

# Check if any changes were made
if (-not $ChangesMade) {
    $message = "No changes have been detected since last run."
    Write-Output $message
    Add-ToLogBuffer -Value $message
}

# Add the separator line to the log buffer at the top
$separator = "===== Script Run on $(Get-Date -AsUTC -Format 'yyyy-MM-dd HH:mm:ss') UTC ====="
$LogBuffer.InsertRange(0, @('', $separator))

# Prepend the collected log entries to the log file
if (Test-Path $LogFilePath) {
    $existingContent = Get-Content -Path $LogFilePath -Raw
    $LogContent = ($LogBuffer -join "`n") + "`n" + $existingContent
    Set-Content -Path $LogFilePath -Value $LogContent
} else {
    # If the file doesn't exist, create it with the log content
    $LogContent = $LogBuffer -join "`n"
    Set-Content -Path $LogFilePath -Value $LogContent
}

# Save the updated $existingFIDOKeys to the JSON file
$UpdatedKeysJson = $existingFIDOKeys | ConvertTo-Json -Depth 100
Set-Content -Path 'Assets/FIDOCTKeys.json' -Value $UpdatedKeysJson

# Calculate counts
$existingKeyCount = $existingFIDOKeys.keys.Count
$FIDOAKeyCount = $FIDOAKeys.entries.Count

# Set outputs for GitHub Actions
$githubOutput = $env:GITHUB_OUTPUT
Add-Content -Path $githubOutput -Value "existingKeyCount=$existingKeyCount"
Add-Content -Path $githubOutput -Value "FIDOAKeyCount=$FIDOAKeyCount"
Add-Content -Path $githubOutput -Value "changesMade=$ChangesMade"
