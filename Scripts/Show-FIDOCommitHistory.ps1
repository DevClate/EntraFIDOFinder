<#
.SYNOPSIS
    Shows AAGUID changes across the last N commits from Microsoft Docs FIDO vendor page.

.DESCRIPTION
    Fetches commit history from the Microsoft Docs GitHub repository for the FIDO vendor page,
    parses the table data from each commit, and displays added/removed/changed AAGUIDs.

.PARAMETER CommitCount
    Number of recent commits to analyze. Default is 3.

.PARAMETER CurrentMonth
    Show all commits from the current month.

.PARAMETER Month
    Show all commits from a specific month (1-12). Requires -Month parameter.

.PARAMETER Year
    Year for the -Month parameter. Default is current year.

.PARAMETER ShowDetails
    Display detailed change information for each AAGUID.

.PARAMETER AsChangeLog
    Format output for changelog

.PARAMETER OutputFile
    Save changelog output to a file. Only valid with -AsChangeLog.

.EXAMPLE
    Show-FIDOCommitHistory

.EXAMPLE
    Show-FIDOCommitHistory -CommitCount 5 -ShowDetails

.EXAMPLE
    Show-FIDOCommitHistory -CurrentMonth -ShowDetails

.EXAMPLE
    Show-FIDOCommitHistory -Month 4 -Year 2026

.EXAMPLE
    Show-FIDOCommitHistory -CurrentMonth -AsChangeLog -OutputFile "CHANGELOG-May2026.md"

.EXAMPLE
    Show-FIDOCommitHistory -Month 4 -Year 2026 -AsChangeLog | Out-File "April2026.md"

.NOTES
    Date: 2026-05-12
#>

Function Show-FIDOCommitHistory {
    [CmdletBinding(DefaultParameterSetName='Count')]
    param (
        [Parameter(ParameterSetName='Count')]
        [int]$CommitCount = 3,
        
        [Parameter(ParameterSetName='CurrentMonth')]
        [switch]$CurrentMonth,
        
        [Parameter(ParameterSetName='SpecificMonth')]
        [ValidateRange(1, 12)]
        [int]$Month,
        
        [Parameter(ParameterSetName='SpecificMonth')]
        [ValidateRange(2020, 2030)]
        [int]$Year = (Get-Date).Year,
        
        [Parameter()]
        [switch]$ShowDetails,
        
        [Parameter()]
        [switch]$AsChangeLog,
        
        [Parameter()]
        [string]$OutputFile
    )

    $ErrorActionPreference = 'Stop'
    
    # GitHub API settings
    $owner = "MicrosoftDocs"
    $repo = "entra-docs"
    $filePath = "docs/identity/authentication/concept-fido2-hardware-vendor.md"
    $apiBase = "https://api.github.com"
    
    # Determine date range based on parameters
    $since = $null
    $until = $null
    $perPage = 100  # Default for date-based queries
    
    if ($CurrentMonth) {
        $now = Get-Date
        $since = Get-Date -Year $now.Year -Month $now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
        $until = $since.AddMonths(1).AddSeconds(-1)
        Write-Host "`n🔍 Fetching commits for current month ($($since.ToString('MMMM yyyy')))..." -ForegroundColor Cyan
    }
    elseif ($PSBoundParameters.ContainsKey('Month')) {
        $since = Get-Date -Year $Year -Month $Month -Day 1 -Hour 0 -Minute 0 -Second 0
        $until = $since.AddMonths(1).AddSeconds(-1)
        Write-Host "`n🔍 Fetching commits for $($since.ToString('MMMM yyyy'))..." -ForegroundColor Cyan
    }
    else {
        $perPage = $CommitCount
        Write-Host "`n🔍 Fetching last $CommitCount commits from Microsoft Docs..." -ForegroundColor Cyan
    }
    
    try {
        # Build commits URL with date filters if specified
        $commitsUrl = "$apiBase/repos/$owner/$repo/commits?path=$filePath&per_page=$perPage"
        if ($since) {
            $commitsUrl += "&since=$($since.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
        }
        if ($until) {
            $commitsUrl += "&until=$($until.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
        }
        
        $commits = Invoke-RestMethod -Uri $commitsUrl -Headers @{
            "Accept" = "application/vnd.github.v3+json"
            "User-Agent" = "PowerShell-FIDO-Tracker"
        }
        
        if ($commits.Count -eq 0) {
            Write-Host "No commits found." -ForegroundColor Yellow
            return
        }
        
        Write-Host "✅ Found $($commits.Count) recent commits`n" -ForegroundColor Green
        
        # Fetch and parse each commit
        $commitData = @()
        
        foreach ($commit in $commits) {
            $sha = $commit.sha
            $date = [DateTime]::Parse($commit.commit.author.date)
            $message = $commit.commit.message
            $author = $commit.commit.author.name
            
            Write-Host "  📥 Fetching commit $($sha.Substring(0,7)) - $($date.ToString('yyyy-MM-dd HH:mm'))..." -ForegroundColor Gray
            
            # Get the file content at this commit
            $fileUrl = "$apiBase/repos/$owner/$repo/contents/$filePath`?ref=$sha"
            $fileData = Invoke-RestMethod -Uri $fileUrl -Headers @{
                "Accept" = "application/vnd.github.v3+json"
                "User-Agent" = "PowerShell-FIDO-Tracker"
            }
            
            # Decode content (it's base64 encoded)
            $content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($fileData.content))
            
            # Parse the markdown table
            $entries = Parse-FIDOTable -Content $content
            
            $commitData += [PSCustomObject]@{
                SHA = $sha
                ShortSHA = $sha.Substring(0, 7)
                Date = $date
                Message = $message
                Author = $author
                Entries = $entries
                AAGUIDs = $entries.AAGUID
            }
        }
        
        # Prepare output based on format
        $outputLines = New-Object System.Collections.ArrayList
        
        if ($AsChangeLog) {
            # Professional changelog format
            $title = if ($CurrentMonth) {
                "# FIDO2 Hardware Vendor Changes - $($commitData[0].Date.ToString('MMMM yyyy'))"
            } elseif ($PSBoundParameters.ContainsKey('Month')) {
                "# FIDO2 Hardware Vendor Changes - $($commitData[0].Date.ToString('MMMM yyyy'))"
            } else {
                "# FIDO2 Hardware Vendor Changes - Recent Updates"
            }
            
            $outputLines.Add($title) | Out-Null
            $outputLines.Add("") | Out-Null
            $outputLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
            $outputLines.Add("Source: [Microsoft Docs FIDO2 Vendor Page](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor)") | Out-Null
            $outputLines.Add("") | Out-Null
            $outputLines.Add("---") | Out-Null
            $outputLines.Add("") | Out-Null
        } else {
            # Display commit information
            Write-Host "`n" + ("=" * 100) -ForegroundColor Cyan
            Write-Host "📊 COMMIT HISTORY ANALYSIS" -ForegroundColor Cyan
            Write-Host ("=" * 100) -ForegroundColor Cyan
        }
        
        for ($i = 0; $i -lt $commitData.Count; $i++) {
            $current = $commitData[$i]
            
            if ($AsChangeLog) {
                $outputLines.Add("## $($current.Date.ToString('yyyy-MM-dd')) - Commit $($current.ShortSHA)") | Out-Null
                $outputLines.Add("") | Out-Null
                $outputLines.Add("**Author:** $($current.Author)") | Out-Null
                $outputLines.Add("**Total AAGUIDs:** $($current.Entries.Count)") | Out-Null
                if ($current.Message -notmatch '^(Update|Fix|Add|Remove)') {
                    $outputLines.Add("**Note:** $($current.Message)") | Out-Null
                }
                $outputLines.Add("") | Out-Null
            } else {
                Write-Host "`n[$($i + 1)] Commit: $($current.ShortSHA)" -ForegroundColor Yellow
                Write-Host "    Date:    $($current.Date.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
                Write-Host "    Author:  $($current.Author)" -ForegroundColor Gray
                Write-Host "    Message: $($current.Message)" -ForegroundColor Gray
                Write-Host "    Entries: $($current.Entries.Count) AAGUIDs" -ForegroundColor Gray
            }
            
            # Compare with previous commit
            if ($i -lt ($commitData.Count - 1)) {
                $previous = $commitData[$i + 1]
                
                if (-not $AsChangeLog) {
                    Write-Host "`n    📈 Changes from previous commit ($($previous.ShortSHA)):" -ForegroundColor Magenta
                }
                
                # Find added AAGUIDs
                $added = $current.Entries | Where-Object { $_.AAGUID -notin $previous.AAGUIDs }
                
                # Find removed AAGUIDs
                $removed = $previous.Entries | Where-Object { $_.AAGUID -notin $current.AAGUIDs }
                
                # Find modified AAGUIDs (present in both but with different properties)
                $modified = @()
                foreach ($entry in $current.Entries) {
                    $prevEntry = $previous.Entries | Where-Object { $_.AAGUID -eq $entry.AAGUID }
                    if ($prevEntry) {
                        $changes = @()
                        foreach ($prop in @('Description', 'Bio', 'USB', 'NFC', 'BLE')) {
                            if ($entry.$prop -ne $prevEntry.$prop) {
                                $changes += "$prop`: '$($prevEntry.$prop)' → '$($entry.$prop)'"
                            }
                        }
                        if ($changes.Count -gt 0) {
                            $modified += [PSCustomObject]@{
                                AAGUID = $entry.AAGUID
                                Description = $entry.Description
                                Changes = $changes
                            }
                        }
                    }
                }
                
                # Display summary
                $totalChanges = $added.Count + $removed.Count + $modified.Count
                
                if ($AsChangeLog) {
                    if ($totalChanges -eq 0) {
                        $outputLines.Add("No changes to FIDO2 hardware vendor table in this commit.") | Out-Null
                        $outputLines.Add("") | Out-Null
                    } else {
                        $outputLines.Add("### Summary") | Out-Null
                        $outputLines.Add("") | Out-Null
                        if ($added.Count -gt 0) {
                            $outputLines.Add("- **Added:** $($added.Count) authenticator(s)") | Out-Null
                        }
                        if ($removed.Count -gt 0) {
                            $outputLines.Add("- **Removed:** $($removed.Count) authenticator(s)") | Out-Null
                        }
                        if ($modified.Count -gt 0) {
                            $outputLines.Add("- **Modified:** $($modified.Count) authenticator(s)") | Out-Null
                        }
                        $outputLines.Add("") | Out-Null
                    }
                    
                    if ($added.Count -gt 0) {
                        $outputLines.Add("### Added Authenticators") | Out-Null
                        $outputLines.Add("") | Out-Null
                        foreach ($item in $added) {
                            $outputLines.Add("#### $($item.Description)") | Out-Null
                            $outputLines.Add("") | Out-Null
                            $outputLines.Add("- **AAGUID:** ``$($item.AAGUID)``") | Out-Null
                            $capabilities = @()
                            if ($item.Bio -eq 'Yes') { $capabilities += 'Biometric' }
                            if ($item.USB -eq 'Yes') { $capabilities += 'USB' }
                            if ($item.NFC -eq 'Yes') { $capabilities += 'NFC' }
                            if ($item.BLE -eq 'Yes') { $capabilities += 'BLE' }
                            $outputLines.Add("- **Capabilities:** $($capabilities -join ', ')") | Out-Null
                            $outputLines.Add("") | Out-Null
                        }
                    }
                    
                    if ($removed.Count -gt 0) {
                        $outputLines.Add("### Removed Authenticators") | Out-Null
                        $outputLines.Add("") | Out-Null
                        foreach ($item in $removed) {
                            $outputLines.Add("- **$($item.Description)**") | Out-Null
                            $outputLines.Add("  - AAGUID: ``$($item.AAGUID)``") | Out-Null
                        }
                        $outputLines.Add("") | Out-Null
                    }
                    
                    if ($modified.Count -gt 0) {
                        $outputLines.Add("### Modified Authenticators") | Out-Null
                        $outputLines.Add("") | Out-Null
                        foreach ($item in $modified) {
                            $outputLines.Add("#### $($item.Description)") | Out-Null
                            $outputLines.Add("") | Out-Null
                            $outputLines.Add("- **AAGUID:** ``$($item.AAGUID)``") | Out-Null
                            foreach ($change in $item.Changes) {
                                $outputLines.Add("- $change") | Out-Null
                            }
                            $outputLines.Add("") | Out-Null
                        }
                    }
                } else {
                    # Console output for non-changelog format
                    if ($totalChanges -gt 0) {
                        if ($ShowDetails) {
                            if ($added.Count -gt 0) {
                                Write-Host "`n       ➕ ADDED:" -ForegroundColor Green
                                foreach ($item in $added) {
                                    Write-Host "          • $($item.Description)" -ForegroundColor White
                                    Write-Host "            AAGUID: $($item.AAGUID)" -ForegroundColor Gray
                                    Write-Host "            Bio: $($item.Bio) | USB: $($item.USB) | NFC: $($item.NFC) | BLE: $($item.BLE)" -ForegroundColor Gray
                                }
                            }
                            
                            if ($removed.Count -gt 0) {
                                Write-Host "`n       ➖ REMOVED:" -ForegroundColor Red
                                foreach ($item in $removed) {
                                    Write-Host "          • $($item.Description)" -ForegroundColor White
                                    Write-Host "            AAGUID: $($item.AAGUID)" -ForegroundColor Gray
                                }
                            }
                            
                            if ($modified.Count -gt 0) {
                                Write-Host "`n       🔄 MODIFIED:" -ForegroundColor Yellow
                                foreach ($item in $modified) {
                                    Write-Host "          • $($item.Description)" -ForegroundColor White
                                    Write-Host "            AAGUID: $($item.AAGUID)" -ForegroundColor Gray
                                    foreach ($change in $item.Changes) {
                                        Write-Host "            - $change" -ForegroundColor Cyan
                                    }
                                }
                            }
                        } else {
                            # Summary without details
                            Write-Host "`n       📊 Changes: " -NoNewline -ForegroundColor Cyan
                            $changeSummary = @()
                            if ($added.Count -gt 0) { $changeSummary += "$($added.Count) added" }
                            if ($removed.Count -gt 0) { $changeSummary += "$($removed.Count) removed" }
                            if ($modified.Count -gt 0) { $changeSummary += "$($modified.Count) modified" }
                            Write-Host ($changeSummary -join ', ') -ForegroundColor White
                        }
                    } else {
                        if (-not $AsChangeLog) {
                            Write-Host "`n       No changes detected" -ForegroundColor Gray
                        }
                    }
                }
            } else {
                if (-not $AsChangeLog) {
                    Write-Host "`n    (Oldest commit in range - no comparison)" -ForegroundColor Gray
                }
            }
        }
        
        # Summary statistics
        if ($AsChangeLog) {
            $outputLines.Add("---") | Out-Null
            $outputLines.Add("") | Out-Null
            $outputLines.Add("## Summary Statistics") | Out-Null
            $outputLines.Add("") | Out-Null
            $outputLines.Add("| Metric | Value |") | Out-Null
            $outputLines.Add("|--------|-------|") | Out-Null
            $outputLines.Add("| Commits Analyzed | $($commitData.Count) |") | Out-Null
            $outputLines.Add("| Date Range | $($commitData[-1].Date.ToString('yyyy-MM-dd')) to $($commitData[0].Date.ToString('yyyy-MM-dd')) |") | Out-Null
            $outputLines.Add("| Current Total AAGUIDs | $($commitData[0].Entries.Count) |") | Out-Null
            if ($commitData.Count -gt 1) {
                $netChange = $commitData[0].Entries.Count - $commitData[-1].Entries.Count
                $changeSymbol = if ($netChange -gt 0) { "+" } elseif ($netChange -lt 0) { "" } else { "" }
                $outputLines.Add("| Net Change | $changeSymbol$netChange |") | Out-Null
            }
            $outputLines.Add("") | Out-Null
            $outputLines.Add("---") | Out-Null
            $outputLines.Add("") | Out-Null
            $outputLines.Add("*This changelog was automatically generated from the [Microsoft Docs FIDO2 Hardware Vendor page](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor).*") | Out-Null
            
            # Output to file or console
            if ($OutputFile) {
                $outputLines | Out-File -FilePath $OutputFile -Encoding utf8
                Write-Host "`n✅ Changelog saved to: $OutputFile" -ForegroundColor Green
            } else {
                $outputLines | ForEach-Object { Write-Output $_ }
            }
        } else {
            Write-Host "`n" + ("=" * 100) -ForegroundColor Cyan
            Write-Host "📈 SUMMARY STATISTICS" -ForegroundColor Cyan
            Write-Host ("=" * 100) -ForegroundColor Cyan
            Write-Host "Total commits analyzed:     $($commitData.Count)" -ForegroundColor White
            Write-Host "Date range:                 $($commitData[-1].Date.ToString('yyyy-MM-dd')) to $($commitData[0].Date.ToString('yyyy-MM-dd'))" -ForegroundColor White
            Write-Host "Current AAGUIDs:            $($commitData[0].Entries.Count)" -ForegroundColor White
            if ($commitData.Count -gt 1) {
                Write-Host "Oldest commit AAGUIDs:      $($commitData[-1].Entries.Count)" -ForegroundColor White
                Write-Host "Net change:                 $($commitData[0].Entries.Count - $commitData[-1].Entries.Count)" -ForegroundColor White
            }
            Write-Host ""
        }
    }
    catch {
        Write-Error "Failed to fetch commit history: $_"
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Error "HTTP Status Code: $statusCode"
            if ($statusCode -eq 403) {
                Write-Host "`n💡 Tip: You may have hit GitHub API rate limits. Try again in a few minutes." -ForegroundColor Yellow
            }
        }
    }
}

function Parse-FIDOTable {
    param([string]$Content)
    
    $entries = @()
    
    # Find the table in markdown (looking for lines with | Description | AAGUID | ...)
    $lines = $Content -split "`r?`n"
    $inTable = $false
    $headers = @()
    
    foreach ($line in $lines) {
        # Detect table header - look for Description and AAGUID
        if ($line -match '^\s*Description\s*\|.*AAGUID.*\|' -or $line -match '^\|\s*Description\s*\|.*AAGUID.*\|') {
            $inTable = $true
            # Parse headers
            $headers = $line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            Write-Verbose "Found table headers: $($headers -join ', ')"
            continue
        }
        
        # Skip separator line
        if ($line -match '^[-:|]+$' -or $line -match '^\s*[-:|]+\s*\|') {
            continue
        }
        
        # Parse table rows
        if ($inTable -and ($line -match '^\s*[^|]+\|' -or $line -match '^\|')) {
            $cells = $line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            
            if ($cells.Count -ge 2) {
                $entry = [PSCustomObject]@{
                    Description = ''
                    AAGUID = ''
                    Bio = ''
                    USB = ''
                    NFC = ''
                    BLE = ''
                }
                
                # Map cells to properties based on headers
                for ($i = 0; $i -lt [Math]::Min($cells.Count, $headers.Count); $i++) {
                    $header = $headers[$i]
                    $value = $cells[$i]
                    
                    # Remove markdown links
                    $value = $value -replace '\[([^\]]+)\]\([^\)]+\)', '$1'
                    $value = $value -replace '\[([^\]]+)\].*', '$1'
                    
                    # Convert HTML entities to readable format
                    $value = $value -replace '&#x2705;|&#9989;', 'Yes'  # Check mark
                    $value = $value -replace '&#10060;|&#x274C;', 'No'  # X mark
                    
                    # Clean up check marks and emojis
                    $value = $value -replace '✅|:white_check_mark:', 'Yes'
                    $value = $value -replace '❌|:x:', 'No'
                    $value = $value.Trim()
                    
                    if ($header -match 'Description') { $entry.Description = $value }
                    elseif ($header -match 'AAGUID') { $entry.AAGUID = $value }
                    elseif ($header -match 'Bio') { $entry.Bio = $value }
                    elseif ($header -match 'USB') { $entry.USB = $value }
                    elseif ($header -match 'NFC') { $entry.NFC = $value }
                    elseif ($header -match 'BLE') { $entry.BLE = $value }
                }
                
                # Only add if we have a valid AAGUID (36 character UUID format)
                if ($entry.AAGUID -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') {
                    $entries += $entry
                }
            }
        }
        
        # Stop when we leave the table (empty line or non-table content after table started)
        if ($inTable -and $line.Trim() -eq '' -and $entries.Count -gt 0) {
            break
        }
    }
    
    Write-Verbose "Parsed $($entries.Count) entries from table"
    return $entries
}

# Run directly if not dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
    Show-FIDOCommitHistory @PSBoundParameters
}
