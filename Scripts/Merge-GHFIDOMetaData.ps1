<#
.SYNOPSIS
Merges FIDO Alliance MDS3 metadata into Assets/FidoKeys.json.

.DESCRIPTION
Downloads the MDS3 blob, and for every AAGUID present in both the MDS3 blob and the local database
updates timeOfLastStatusChange, metadataStatement and statusReports. Changes are logged to a log file
(newest run first). Aborts before writing anything if the MDS3 data is empty or matches none of the
local AAGUIDs. Sets metadata.databaseLastChecked on every run and metadata.databaseLastUpdated when
something changed. Run from the repository root; all parameters are optional.

.PARAMETER ExistingKeyFile
Path to the local FIDO key database.

.PARAMETER LogFilePath
Path to the merge log that is prepended to on each run.

.PARAMETER FIDOUri
MDS3 endpoint to download.

.PARAMETER MdsData
Already decoded MDS3 payload (object with an 'entries' collection). Skips the download; mainly for tests.
#>
[CmdletBinding()]
param (
    [string]$ExistingKeyFile = 'Assets/FidoKeys.json',
    [string]$LogFilePath = 'FAmerge_log.txt',
    [string]$FIDOUri = 'https://mds3.fidoalliance.org/',
    [psobject]$MdsData
)

$ErrorActionPreference = 'Stop'

# Load existing FIDO keys from local JSON file
try {
    $existingFIDOKeys = Get-Content -Path $ExistingKeyFile -Raw | ConvertFrom-Json -Depth 100
}
catch {
    Write-Error "Failed to load FIDO keys from '$ExistingKeyFile': $_" -ErrorAction Stop
}

# Fetch FIDO Alliance keys from the MDS3 endpoint (unless supplied)
if ($MdsData) {
    $FIDOAKeys = $MdsData
}
else {
    try {
        $FIDOAURL = Invoke-WebRequest -Uri $FIDOUri -ErrorAction Stop
        $FIDOAKeys = $FIDOAURL | Get-JWTDetails
    }
    catch {
        Write-Error "Failed to fetch FIDO Alliance data from '$FIDOUri': $_" -ErrorAction Stop
    }
}

# Initialize the log buffer as an ArrayList
$LogBuffer = New-Object System.Collections.ArrayList

# Initialize the changes tracking variable
$ChangesMade = $false

# Guard: never merge an empty or unusable MDS payload
if (-not $FIDOAKeys -or @($FIDOAKeys.entries).Count -eq 0) {
    Write-Error "FIDO Alliance data from '$FIDOUri' contains no entries. Aborting without changes." -ErrorAction Stop
}

# Index MDS entries and existing keys by AAGUID (first occurrence wins)
$mdsIndex = @{}
foreach ($entry in @($FIDOAKeys.entries)) {
    if (-not $entry.aaguid) { continue }
    $id = "$($entry.aaguid)".ToLowerInvariant()
    if ($mdsIndex.ContainsKey($id)) {
        Write-Warning "Duplicate AAGUID $id in MDS data; keeping the first entry."
    }
    else {
        $mdsIndex[$id] = $entry
    }
}
$existingIndex = @{}
foreach ($key in @($existingFIDOKeys.keys)) {
    if (-not $key.AAGUID) { continue }
    $id = "$($key.AAGUID)".ToLowerInvariant()
    if (-not $existingIndex.ContainsKey($id)) {
        $existingIndex[$id] = $key
    }
}

# Create a list of common AAGUIDs between existing keys and FIDO Alliance keys
$CommonAAGUIDs = @($existingIndex.Keys | Where-Object { $mdsIndex.ContainsKey($_) })
if ($CommonAAGUIDs.Count -eq 0) {
    Write-Error "None of the existing AAGUIDs were found in the FIDO Alliance data. Aborting without changes." -ErrorAction Stop
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

# Logs a multi-line change record and flags that changes were made
function Write-BlockChange {
    param ($AAGUID, $Path, $Old, $New)
    $timestamp = Get-Timestamp
    $oldStr = ConvertTo-Json -InputObject $Old -Depth 100
    $newStr = ConvertTo-Json -InputObject $New -Depth 100
    $logMessage = @"
$timestamp - AAGUID: $AAGUID
Path: $Path
Old Value:
$oldStr

New Value:
$newStr

"@
    Write-Output $logMessage
    Add-ToLogBuffer -Value $logMessage
    $script:ChangesMade = $true
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

        # Property no longer present upstream: remove it
        if (-not $obj2.Value.PSObject.Properties[$name]) {
            if ($update) {
                Write-BlockChange -AAGUID $AAGUID -Path $currentPath -Old $value1 -New $null
                $obj1.Value.PSObject.Properties.Remove($name)
            }
            continue
        }

        if ($value1 -is [PSCustomObject] -or $value1 -is [Array]) {
            $bothArrays = $value1 -is [Array] -and $value2 -is [Array]
            $bothObjects = $value1 -is [PSCustomObject] -and $value2 -is [PSCustomObject]
            $hasObjectItems = $bothArrays -and (@($value1 + $value2) | Where-Object { $_ -is [PSCustomObject] })
            if ($bothArrays -and $value1.Count -eq $value2.Count -and $hasObjectItems) {
                for ($i = 0; $i -lt $value1.Count; $i++) {
                    $item1 = $value1[$i]
                    $item2 = $value2[$i]
                    if ($item1 -is [PSCustomObject] -and $item2 -is [PSCustomObject]) {
                        Compare-Objects -obj1 ([ref]$item1) -obj2 ([ref]$item2) -path "$currentPath`[$i`]" -update:$update -AAGUID $AAGUID
                    }
                    elseif ((ConvertTo-Json -InputObject $item1 -Depth 100 -Compress) -ne (ConvertTo-Json -InputObject $item2 -Depth 100 -Compress)) {
                        if ($update) {
                            Write-BlockChange -AAGUID $AAGUID -Path "$currentPath`[$i`]" -Old $item1 -New $item2
                            $value1[$i] = $item2
                        }
                    }
                }
            }
            elseif ($bothObjects) {
                Compare-Objects -obj1 ([ref]$value1) -obj2 ([ref]$value2) -path $currentPath -update:$update -AAGUID $AAGUID
            }
            else {
                # Arrays of scalars, arrays of different length, or a type change: compare as a whole
                $old = ConvertTo-Json -InputObject $value1 -Depth 100 -Compress
                $new = ConvertTo-Json -InputObject $value2 -Depth 100 -Compress
                if ($old -ne $new -and $update) {
                    Write-BlockChange -AAGUID $AAGUID -Path $currentPath -Old $value1 -New $value2
                    if ($prop.IsSettable) {
                        $obj1.Value.$name = $value2
                    }
                }
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

    # Properties that exist upstream but not locally are added
    $localNames = @($obj1.Value.PSObject.Properties.Name)
    foreach ($upstream in $obj2.Value.PSObject.Properties) {
        if ($upstream.MemberType -ne 'NoteProperty' -or $excludedProperties -contains $upstream.Name -or $localNames -contains $upstream.Name) { continue }
        if ($update) {
            $currentPath = if ($path) { "$path.$($upstream.Name)" } else { $upstream.Name }
            Write-BlockChange -AAGUID $AAGUID -Path $currentPath -Old $null -New $upstream.Value
            $obj1.Value | Add-Member -MemberType NoteProperty -Name $upstream.Name -Value $upstream.Value
        }
    }
}

# Main comparison and update loop
foreach ($AAGUIDKey in $CommonAAGUIDs) {
    # Get the entries with the current AAGUID
    $EXXXKey = $existingIndex[$AAGUIDKey]
    $FAAAKey = $mdsIndex[$AAGUIDKey]
    $AAGUID = $EXXXKey.AAGUID

    if ($EXXXKey -and $FAAAKey) {
        # Check if timeOfLastStatusChange property exists, and add it if it doesn't
        $hasProperty = $EXXXKey.PSObject.Properties.Name -contains "timeOfLastStatusChange"

        # Update timeOfLastStatusChange if different
        if ($hasProperty -and $EXXXKey.timeOfLastStatusChange -ne $FAAAKey.timeOfLastStatusChange) {
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
        # If property doesn't exist but FAAA has it, add it
        elseif (-not $hasProperty -and $FAAAKey.timeOfLastStatusChange) {
            $timestamp = Get-Timestamp
            $logMessage = @"
$timestamp - AAGUID: $AAGUID
Adding timeOfLastStatusChange property
New Value:
$($FAAAKey.timeOfLastStatusChange)

"@
            Write-Output $logMessage
            Add-ToLogBuffer -Value $logMessage
            
            # Add the property to the object
            $EXXXKey | Add-Member -MemberType NoteProperty -Name 'timeOfLastStatusChange' -Value $FAAAKey.timeOfLastStatusChange
            
            # Set the changes made flag to true
            $script:ChangesMade = $true
        }

        # Normalize versions if metadataStatement exists
        if ($EXXXKey.PSObject.Properties.Name -contains "metadataStatement" -and $EXXXKey.metadataStatement) {
            $EXXXKey.metadataStatement = Normalize-Versions $EXXXKey.metadataStatement
        }
        
        if ($FAAAKey.PSObject.Properties.Name -contains "metadataStatement" -and $FAAAKey.metadataStatement) {
            $FAAAKey.metadataStatement = Normalize-Versions $FAAAKey.metadataStatement
        }
        
        # Check if EXXX entry has no metadataStatement but FAAA does
        $hasMetadataStatement = $EXXXKey.PSObject.Properties.Name -contains 'metadataStatement'
        if ((-not $hasMetadataStatement -or -not $EXXXKey.metadataStatement) -and $FAAAKey.metadataStatement) {
            $timestamp = Get-Timestamp
            $logMessage = @"
$timestamp - AAGUID: $AAGUID
Adding metadataStatement from FAAA to EXXX entry
Vendor: $($EXXXKey.Vendor)
Description: $($EXXXKey.Description)

"@
            Write-Output $logMessage
            Add-ToLogBuffer -Value $logMessage
            
            # Add or set metadataStatement property
            if (-not $hasMetadataStatement) {
                $EXXXKey | Add-Member -MemberType NoteProperty -Name 'metadataStatement' -Value $FAAAKey.metadataStatement
            } else {
                $EXXXKey.metadataStatement = $FAAAKey.metadataStatement
            }
            
            # Set the changes made flag to true
            $script:ChangesMade = $true
        }
        
        # Remove null properties that aren't needed
        if ($EXXXKey.PSObject.Properties.Name -contains 'authenticatorGetInfo' -and -not $EXXXKey.authenticatorGetInfo) {
            $EXXXKey.PSObject.Properties.Remove("authenticatorGetInfo")
            $script:ChangesMade = $true
        }
        
        if ($EXXXKey.PSObject.Properties.Name -contains 'statusReports' -and -not $EXXXKey.statusReports) {
            # If we have status reports in FAAA, copy them over
            if ($FAAAKey.statusReports) {
                $EXXXKey.statusReports = $FAAAKey.statusReports
            } else {
                # Otherwise, remove the null property
                $EXXXKey.PSObject.Properties.Remove('statusReports')
            }
            $script:ChangesMade = $true
        }
        
        # If timeOfLastStatusChange is null but exists in FAAA, copy it over
        if ($EXXXKey.PSObject.Properties.Name -contains 'timeOfLastStatusChange' -and 
            -not $EXXXKey.timeOfLastStatusChange -and 
            $FAAAKey.timeOfLastStatusChange) {
            $EXXXKey.timeOfLastStatusChange = $FAAAKey.timeOfLastStatusChange
            $script:ChangesMade = $true
        }

        # Compare and update metadataStatement if both exist
        if ($EXXXKey.PSObject.Properties.Name -contains 'metadataStatement' -and 
            $EXXXKey.metadataStatement -and 
            $FAAAKey.metadataStatement) {
            Compare-Objects -obj1 ([ref]$EXXXKey.metadataStatement) -obj2 ([ref]$FAAAKey.metadataStatement) -update -AAGUID $AAGUID
        }

        # Compare and update statusReports if both exist
        if ($EXXXKey.PSObject.Properties.Name -contains 'statusReports' -and 
            $FAAAKey.PSObject.Properties.Name -contains 'statusReports' -and
            $EXXXKey.statusReports -and 
            $FAAAKey.statusReports) {
            Compare-Objects -obj1 ([ref]$EXXXKey.statusReports) -obj2 ([ref]$FAAAKey.statusReports) -path 'statusReports' -update -AAGUID $AAGUID
        }
    } # End of if ($EXXXKey -and $FAAAKey) block
} # End of foreach loop

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

# Record database check/update times
$now = Get-Timestamp
if (-not $existingFIDOKeys.metadata) {
    $existingFIDOKeys | Add-Member -MemberType NoteProperty -Name 'metadata' -Value ([PSCustomObject]@{}) -Force
}
$fieldsToStamp = @('databaseLastChecked')
if ($ChangesMade) { $fieldsToStamp += 'databaseLastUpdated' }
foreach ($field in $fieldsToStamp) {
    if ($existingFIDOKeys.metadata.PSObject.Properties[$field]) {
        $existingFIDOKeys.metadata.$field = $now
    }
    else {
        $existingFIDOKeys.metadata | Add-Member -MemberType NoteProperty -Name $field -Value $now
    }
}

# Save the updated $existingFIDOKeys to the JSON file first (atomically), then the log
try {
    $UpdatedKeysJson = $existingFIDOKeys | ConvertTo-Json -Depth 100
    $tmpFile = "$ExistingKeyFile.tmp"
    Set-Content -Path $tmpFile -Value $UpdatedKeysJson -Encoding utf8
    Move-Item -Path $tmpFile -Destination $ExistingKeyFile -Force
}
catch {
    Write-Error "Failed to save updated FIDO keys to '$ExistingKeyFile': $_" -ErrorAction Stop
}

# Add the separator line to the log buffer at the top
$separator = "===== Script Run on $(Get-Date -AsUTC -Format 'yyyy-MM-dd HH:mm:ss') UTC ====="
$LogBuffer.InsertRange(0, @('', $separator))

# Prepend the collected log entries to the log file
try {
    if (Test-Path -Path $LogFilePath) {
        $existingContent = Get-Content -Path $LogFilePath -Raw
        $LogContent = ($LogBuffer -join "`n") + "`n" + $existingContent
        Set-Content -Path $LogFilePath -Value $LogContent -Encoding utf8
    }
    else {
        # If the file doesn't exist, create it with the log content
        $LogContent = $LogBuffer -join "`n"
        Set-Content -Path $LogFilePath -Value $LogContent -Encoding utf8
    }
}
catch {
    Write-Error "Failed to write to log file '$LogFilePath': $_" -ErrorAction Stop
}

# Calculate counts
$existingKeyCount = $existingFIDOKeys.keys.Count
$FIDOAKeyCount = $FIDOAKeys.entries.Count

# Set outputs for GitHub Actions
if ($env:GITHUB_OUTPUT) {
    try {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "existingKeyCount=$existingKeyCount" -Encoding utf8
        Add-Content -Path $env:GITHUB_OUTPUT -Value "FIDOAKeyCount=$FIDOAKeyCount" -Encoding utf8
        Add-Content -Path $env:GITHUB_OUTPUT -Value "changesMade=$ChangesMade" -Encoding utf8
    }
    catch {
        Write-Warning "Failed to write to GitHub Actions output file: $_"
    }
}
else {
    Write-Verbose "GITHUB_OUTPUT environment variable not set. Skipping GitHub Actions output."
}
