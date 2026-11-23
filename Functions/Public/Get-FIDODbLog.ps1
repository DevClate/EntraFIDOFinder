<#
.SYNOPSIS
Fetches and parses a FIDO database log from a specified URL.

.DESCRIPTION
The Get-FIDODbLog function retrieves a log file from a given URL and parses its content. 
The log entries are expected to follow a specific format, with each entry starting with a date and time stamp.
Entries are categorized by lines starting with "Duplicate" or "Updated". The function returns parsed log entries as objects.

.PARAMETER Url
The URL from which to fetch the log file. Defaults to "https://raw.githubusercontent.com/DevClate/EntraFIDOFinder/main/merge_log.md".

.EXAMPLE
PS> Get-FIDODbLog
Fetches the log file from the default URL and displays the parsed log entries.

.EXAMPLE
PS> Get-FIDODbLog -Url "https://example.com/path/to/log.md"
Fetches the log file from the specified URL and displays the parsed log entries.

.NOTES
Author: DevClate
Date: 2024-10-12
#>
function Get-FIDODbLog {
    [CmdletBinding()]
    param (
        [string]$Url = "https://raw.githubusercontent.com/DevClate/EntraFIDOFinder/main/merge_log.md"
    )

    try {
        # Fetching log file from URL
        $logContent = Invoke-RestMethod -Uri $Url

        if ($logContent) {
            # Split the log content into lines
            $logLines = $logContent -split "`n"

            # Initialize variables
            $logs = @()
            $currentDate = $null
            $currentEntry = ""

            # Parse the log lines
            foreach ($line in $logLines) {
                if ($line -match "^# Merge Log - (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})$") {
                    # New log submission date and time
                    if ($currentDate) {
                        if ($currentEntry -ne "") {
                            $logs += [PSCustomObject]@{
                                Date = $currentDate
                                Entry = $currentEntry.Trim()
                            }
                            $currentEntry = ""
                        }
                    }
                    $currentDate = $matches[1]
                } elseif ($line -eq "") {
                    # Blank line indicates a new log entry
                    if ($currentEntry -ne "") {
                        $logs += [PSCustomObject]@{
                            Date = $currentDate
                            Entry = $currentEntry.Trim()
                        }
                        $currentEntry = ""
                    }
                } elseif ($line -match "^(Duplicate|Updated)") {
                    # New log entry for lines starting with "Duplicate" or "Updated"
                    if ($currentEntry -ne "") {
                        $logs += [PSCustomObject]@{
                            Date = $currentDate
                            Entry = $currentEntry.Trim()
                        }
                        $currentEntry = ""
                    }
                    $currentEntry += "$line`n"
                } else {
                    # Append line to the current entry
                    $currentEntry += "$line`n"
                }
            }

            # Add the last log entry
            if ($currentDate -and $currentEntry -ne "") {
                $logs += [PSCustomObject]@{
                    Date = $currentDate
                    Entry = $currentEntry.Trim()
                }
            }

            $logs
        } else {
            Write-Warning "No content found at the specified URL."
        }
    } catch {
        Write-Error "An error occurred while fetching or parsing the log file: $_"
    }
}