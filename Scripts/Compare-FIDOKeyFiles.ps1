<#
.SYNOPSIS
    Compares two FIDO key JSON files and shows what changed between them.

.DESCRIPTION
    Takes two JSON files (old and current) and compares the FIDO keys to identify
    added, removed, and modified AAGUIDs. Can output in console format or as a
    professional changelog suitable for documentation.

.PARAMETER OldFile
    Path to the older JSON file to compare from.

.PARAMETER CurrentFile
    Path to the current/newer JSON file to compare to.
    Default is 'Assets/FidoKeys.json'.

.PARAMETER ShowDetails
    Display detailed change information for each AAGUID.

.PARAMETER AsChangeLog
    Format output as a professional changelog suitable for documentation.
    Automatically enables detailed output.

.PARAMETER OutputFile
    Save changelog output to a file. Only valid with -AsChangeLog.

.EXAMPLE
    Compare-FIDOKeyFiles -OldFile "backup/FidoKeys-2026-01-01.json"

.EXAMPLE
    Compare-FIDOKeyFiles -OldFile "backup/FidoKeys-2026-01-01.json" -ShowDetails

.EXAMPLE
    Compare-FIDOKeyFiles -OldFile "backup/FidoKeys-2026-01-01.json" -AsChangeLog -OutputFile "CHANGELOG.md"

.EXAMPLE
    # Compare with a specific backup
    Compare-FIDOKeyFiles -OldFile "Assets/FidoKeys.json.bak" -CurrentFile "Assets/FidoKeys.json"

.NOTES
    Author: GitHub Copilot
    Date: 2026-05-24
#>

Function Compare-FIDOKeyFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        [string]$OldFile,
        
        [Parameter()]
        [ValidateScript({Test-Path $_})]
        [string]$CurrentFile = "Assets/FidoKeys.json",
        
        [Parameter()]
        [switch]$ShowDetails,
        
        [Parameter()]
        [switch]$AsChangeLog,
        
        [Parameter()]
        [string]$OutputFile
    )

    $ErrorActionPreference = 'Stop'
    
    # Load JSON files
    Write-Host "`n📂 Loading JSON files..." -ForegroundColor Cyan
    
    try {
        $oldData = Get-Content -Raw -Path $OldFile | ConvertFrom-Json
        $currentData = Get-Content -Raw -Path $CurrentFile | ConvertFrom-Json
        
        $oldEntries = $oldData.keys
        $currentEntries = $currentData.keys
        
        Write-Host "   Old file:     $(Split-Path -Leaf $OldFile) - $($oldEntries.Count) AAGUIDs" -ForegroundColor Gray
        Write-Host "   Current file: $(Split-Path -Leaf $CurrentFile) - $($currentEntries.Count) AAGUIDs" -ForegroundColor Gray
        
        # Get timestamps from metadata if available
        $oldDate = if ($oldData.metadata.databaseLastUpdated) {
            [DateTime]::Parse($oldData.metadata.databaseLastUpdated)
        } else {
            (Get-Item $OldFile).LastWriteTime
        }
        
        $currentDate = if ($currentData.metadata.databaseLastUpdated) {
            [DateTime]::Parse($currentData.metadata.databaseLastUpdated)
        } else {
            (Get-Item $CurrentFile).LastWriteTime
        }
        
    }
    catch {
        Write-Error "Failed to load JSON files: $_"
        return
    }
    
    # Index entries by AAGUID
    $oldByAAGUID = @{}
    foreach ($entry in $oldEntries) {
        $oldByAAGUID[$entry.AAGUID] = $entry
    }
    
    $currentByAAGUID = @{}
    foreach ($entry in $currentEntries) {
        $currentByAAGUID[$entry.AAGUID] = $entry
    }
    
    # Find differences
    Write-Host "🔍 Analyzing differences...`n" -ForegroundColor Cyan
    
    # Find added AAGUIDs
    $added = $currentEntries | Where-Object { $_.AAGUID -notin $oldByAAGUID.Keys }
    
    # Find removed AAGUIDs
    $removed = $oldEntries | Where-Object { $_.AAGUID -notin $currentByAAGUID.Keys }
    
    # Find modified AAGUIDs (present in both but with different properties)
    $modified = @()
    foreach ($entry in $currentEntries) {
        if ($oldByAAGUID.ContainsKey($entry.AAGUID)) {
            $oldEntry = $oldByAAGUID[$entry.AAGUID]
            $changes = @()
            foreach ($prop in @('Description', 'Vendor', 'Bio', 'USB', 'NFC', 'BLE', 'ValidVendor')) {
                if ($entry.$prop -ne $oldEntry.$prop) {
                    $changes += "$prop`: '$($oldEntry.$prop)' → '$($entry.$prop)'"
                }
            }
            if ($changes.Count -gt 0) {
                $modified += [PSCustomObject]@{
                    AAGUID = $entry.AAGUID
                    Description = $entry.Description
                    Vendor = $entry.Vendor
                    Changes = $changes
                }
            }
        }
    }
    
    $totalChanges = $added.Count + $removed.Count + $modified.Count
    
    # Prepare output
    $outputLines = New-Object System.Collections.ArrayList
    
    if ($AsChangeLog) {
        # Professional changelog format matching CHANGELOG.md pattern
        
        # Helper function to convert Yes/No to emoji
        function ConvertTo-Emoji {
            param($value)
            if ($value -eq 'Yes' -or $value -eq '✅') { return '✅' }
            else { return '❌' }
        }
        
        $outputLines.Add("# Changelog") | Out-Null
        $outputLines.Add("") | Out-Null
        $outputLines.Add("## Comparison Results") | Out-Null
        $outputLines.Add("") | Out-Null
        
        if ($totalChanges -eq 0) {
            $outputLines.Add("No changes detected between the two files.") | Out-Null
            $outputLines.Add("") | Out-Null
            $outputLines.Add("**Files Compared:**") | Out-Null
            $outputLines.Add("- Old: $(Split-Path -Leaf $OldFile) ($($oldDate.ToString('yyyy-MM-dd')))") | Out-Null
            $outputLines.Add("- Current: $(Split-Path -Leaf $CurrentFile) ($($currentDate.ToString('yyyy-MM-dd')))") | Out-Null
            $outputLines.Add("") | Out-Null
        } else {
            # Build summary description
            $summaryParts = @()
            if ($added.Count -gt 0) { $summaryParts += "$($added.Count) new authenticator$($added.Count -gt 1 ? 's' : '') added" }
            if ($modified.Count -gt 0) { $summaryParts += "$($modified.Count) authenticator$($modified.Count -gt 1 ? 's' : '') updated" }
            if ($removed.Count -gt 0) { $summaryParts += "$($removed.Count) authenticator$($removed.Count -gt 1 ? 's' : '') removed" }
            
            $outputLines.Add(($summaryParts -join ', ') + " between $(Split-Path -Leaf $OldFile) and $(Split-Path -Leaf $CurrentFile)!") | Out-Null
            $outputLines.Add("") | Out-Null
            
            # Summary bullets
            if ($added.Count -gt 0) {
                $outputLines.Add("- **$($added.Count) new authenticator$($added.Count -gt 1 ? 's have' : ' has')** been added to the supported vendors list") | Out-Null
            }
            if ($modified.Count -gt 0) {
                $outputLines.Add("- **$($modified.Count) authenticator$($modified.Count -gt 1 ? 's have' : ' has')** been updated with new capability information") | Out-Null
            }
            if ($removed.Count -gt 0) {
                $outputLines.Add("- **$($removed.Count) authenticator$($removed.Count -gt 1 ? 's have' : ' has')** been removed from the supported vendors list") | Out-Null
            }
            $outputLines.Add("") | Out-Null
            
            # Added authenticators
            if ($added.Count -gt 0) {
                $outputLines.Add("## ✅ New Authenticators ($($added.Count))") | Out-Null
                $outputLines.Add("") | Out-Null
                $outputLines.Add("The following authenticators are now supported:") | Out-Null
                $outputLines.Add("") | Out-Null
                
                foreach ($item in $added) {
                    $outputLines.Add("### $($item.Description)") | Out-Null
                    $outputLines.Add("") | Out-Null
                    $outputLines.Add("**AAGUID:** ``$($item.AAGUID)``") | Out-Null
                    $outputLines.Add("") | Out-Null
                    $outputLines.Add("**Supported Interfaces:**") | Out-Null
                    $outputLines.Add("") | Out-Null
                    $outputLines.Add("| Interface | Supported |") | Out-Null
                    $outputLines.Add("|-----------|-----------|") | Out-Null
                    $outputLines.Add("| Biometric | $(ConvertTo-Emoji $item.Bio) |") | Out-Null
                    $outputLines.Add("| USB | $(ConvertTo-Emoji $item.USB) |") | Out-Null
                    $outputLines.Add("| NFC | $(ConvertTo-Emoji $item.NFC) |") | Out-Null
                    $outputLines.Add("| BLE | $(ConvertTo-Emoji $item.BLE) |") | Out-Null
                    $outputLines.Add("") | Out-Null
                }
            }
            
            # Modified authenticators
            if ($modified.Count -gt 0) {
                $outputLines.Add("## ⚠️  Updated Authenticators ($($modified.Count))") | Out-Null
                $outputLines.Add("") | Out-Null
                $outputLines.Add("The following authenticators have been updated with new capability information:") | Out-Null
                $outputLines.Add("") | Out-Null
                
                foreach ($item in $modified) {
                    $outputLines.Add("### $($item.Description)") | Out-Null
                    $outputLines.Add("") | Out-Null
                    $outputLines.Add("**AAGUID:** ``$($item.AAGUID)``") | Out-Null
                    $outputLines.Add("") | Out-Null
                    $outputLines.Add("**Changes:**") | Out-Null
                    $outputLines.Add("") | Out-Null
                    
                    # Parse changes and format with emojis
                    foreach ($change in $item.Changes) {
                        # Extract property and values (format: "Property: 'oldval' → 'newval'")
                        if ($change -match "^([^:]+):\s*'([^']*)'[^']*'([^']*)'") {
                            $prop = $matches[1]
                            $oldVal = $matches[2]
                            $newVal = $matches[3]
                            
                            # Convert values to emojis if they're Bio/USB/NFC/BLE properties
                            if ($prop -in @('Bio', 'USB', 'NFC', 'BLE')) {
                                $oldEmoji = ConvertTo-Emoji $oldVal
                                $newEmoji = ConvertTo-Emoji $newVal
                                $outputLines.Add("- $prop`: $oldEmoji → $newEmoji") | Out-Null
                            } else {
                                # For other properties (Description, Vendor, ValidVendor), show as-is
                                $outputLines.Add("- $change") | Out-Null
                            }
                        } else {
                            $outputLines.Add("- $change") | Out-Null
                        }
                    }
                    $outputLines.Add("") | Out-Null
                }
            }
            
            # Removed authenticators
            if ($removed.Count -gt 0) {
                $outputLines.Add("## ❌ Removed Authenticators ($($removed.Count))") | Out-Null
                $outputLines.Add("") | Out-Null
                $outputLines.Add("The following authenticators have been removed:") | Out-Null
                $outputLines.Add("") | Out-Null
                
                foreach ($item in $removed) {
                    $outputLines.Add("### $($item.Description)") | Out-Null
                    $outputLines.Add("") | Out-Null
                    $outputLines.Add("**AAGUID:** ``$($item.AAGUID)``") | Out-Null
                    $outputLines.Add("") | Out-Null
                }
            }
        }
        
        # Output to file or console
        if ($OutputFile) {
            $outputLines | Out-File -FilePath $OutputFile -Encoding utf8
            Write-Host "✅ Changelog saved to: $OutputFile" -ForegroundColor Green
        } else {
            $outputLines | ForEach-Object { Write-Output $_ }
        }
        
    } else {
        # Console format with colors
        Write-Host ("=" * 100) -ForegroundColor Cyan
        Write-Host "📊 COMPARISON RESULTS" -ForegroundColor Cyan
        Write-Host ("=" * 100) -ForegroundColor Cyan
        Write-Host ""
        
        if ($totalChanges -eq 0) {
            Write-Host "✅ No changes detected between the two files." -ForegroundColor Green
        } else {
            Write-Host "📈 Summary:" -ForegroundColor Magenta
            Write-Host "   • Added:    $($added.Count)" -ForegroundColor Green
            Write-Host "   • Removed:  $($removed.Count)" -ForegroundColor Red
            Write-Host "   • Modified: $($modified.Count)" -ForegroundColor Yellow
            Write-Host "   • Total:    $totalChanges changes" -ForegroundColor White
            
            if ($ShowDetails -or $AsChangeLog) {
                if ($added.Count -gt 0) {
                    Write-Host "`n➕ ADDED ($($added.Count)):" -ForegroundColor Green
                    foreach ($item in $added) {
                        Write-Host "   • $($item.Description)" -ForegroundColor White
                        Write-Host "     AAGUID: $($item.AAGUID)" -ForegroundColor Gray
                        Write-Host "     Vendor: $($item.Vendor)" -ForegroundColor Gray
                        Write-Host "     Bio: $($item.Bio) | USB: $($item.USB) | NFC: $($item.NFC) | BLE: $($item.BLE)" -ForegroundColor Gray
                    }
                }
                
                if ($removed.Count -gt 0) {
                    Write-Host "`n➖ REMOVED ($($removed.Count)):" -ForegroundColor Red
                    foreach ($item in $removed) {
                        Write-Host "   • $($item.Description)" -ForegroundColor White
                        Write-Host "     AAGUID: $($item.AAGUID)" -ForegroundColor Gray
                        Write-Host "     Vendor: $($item.Vendor)" -ForegroundColor Gray
                    }
                }
                
                if ($modified.Count -gt 0) {
                    Write-Host "`n🔄 MODIFIED ($($modified.Count)):" -ForegroundColor Yellow
                    foreach ($item in $modified) {
                        Write-Host "   • $($item.Description)" -ForegroundColor White
                        Write-Host "     AAGUID: $($item.AAGUID)" -ForegroundColor Gray
                        Write-Host "     Vendor: $($item.Vendor)" -ForegroundColor Gray
                        foreach ($change in $item.Changes) {
                            Write-Host "     - $change" -ForegroundColor Cyan
                        }
                    }
                }
            }
        }
        
        Write-Host "`n" + ("=" * 100) -ForegroundColor Cyan
        Write-Host "📈 STATISTICS" -ForegroundColor Cyan
        Write-Host ("=" * 100) -ForegroundColor Cyan
        Write-Host "Old file AAGUIDs:     $($oldEntries.Count)" -ForegroundColor White
        Write-Host "Current file AAGUIDs: $($currentEntries.Count)" -ForegroundColor White
        Write-Host "Net change:           $($currentEntries.Count - $oldEntries.Count)" -ForegroundColor White
        Write-Host "Old file date:        $($oldDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host "Current file date:    $($currentDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host ""
    }
}
