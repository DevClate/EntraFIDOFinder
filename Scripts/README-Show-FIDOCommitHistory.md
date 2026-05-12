# Show-FIDOCommitHistory

PowerShell script to analyze FIDO AAGUID changes across commits from the Microsoft Docs FIDO vendor page.

## Description

This script fetches commit history from the [Microsoft Docs Entra FIDO2 vendor documentation](https://github.com/MicrosoftDocs/entra-docs/blob/main/docs/identity/authentication/concept-fido2-hardware-vendor.md) and analyzes changes to AAGUIDs (Authenticator Attestation Globally Unique Identifiers) across commits.

## Features

- ✅ Fetches commits directly from GitHub API (no local clone needed)
- 📊 Parses markdown tables to extract FIDO key data
- 🔍 Detects added, removed, and modified AAGUIDs
- 🎨 Color-coded output for easy reading
- 📈 Summary statistics across commit range

## Usage

### Basic Usage (Last 3 Commits)

```powershell
. ./Scripts/Show-FIDOCommitHistory.ps1
Show-FIDOCommitHistory
```

### Analyze More Commits

```powershell
. ./Scripts/Show-FIDOCommitHistory.ps1
Show-FIDOCommitHistory -CommitCount 10
```

### Show Current Month's Changes

```powershell
. ./Scripts/Show-FIDOCommitHistory.ps1
Show-FIDOCommitHistory -CurrentMonth
```

### Show Specific Month

```powershell
. ./Scripts/Show-FIDOCommitHistory.ps1
# April 2026
Show-FIDOCommitHistory -Month 4 -Year 2026

# Current year (default)
Show-FIDOCommitHistory -Month 3
```

### Show Detailed Changes

```powershell
. ./Scripts/Show-FIDOCommitHistory.ps1
Show-FIDOCommitHistory -CommitCount 5 -ShowDetails

# Or with month filter
Show-FIDOCommitHistory -CurrentMonth -ShowDetails
```

### Generate Professional Changelog

```powershell
. ./Scripts/Show-FIDOCommitHistory.ps1

# Output to console
Show-FIDOCommitHistory -CurrentMonth -AsChangeLog

# Save to file
Show-FIDOCommitHistory -Month 4 -Year 2026 -AsChangeLog -OutputFile "CHANGELOG-April2026.md"

# Or pipe to file
Show-FIDOCommitHistory -CurrentMonth -AsChangeLog > "CHANGELOG-$(Get-Date -Format 'yyyy-MM').md"
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `CommitCount` | int | 3 | Number of recent commits to analyze |
| `CurrentMonth` | switch | false | Show all commits from the current month |
| `Month` | int | - | Show all commits from a specific month (1-12) |
| `Year` | int | Current year | Year for the `-Month` parameter |
| `ShowDetails` | switch | false | Display detailed information for each AAGUID change |
| `AsChangeLog` | switch | false | Format output as a professional changelog (implies ShowDetails) |
| `OutputFile` | string | - | Save changelog output to a file (only with -AsChangeLog) |

**Parameter Sets:**
- Use `-CommitCount` for a specific number of recent commits (default)
- Use `-CurrentMonth` to see all commits from the current month
- Use `-Month` (and optionally `-Year`) to see all commits from a specific month
- Add `-AsChangeLog` to any set for professional documentation format

## Example Output

### Current Month Example

```5 recent commits

====================================================================================================
📊 COMMIT HISTORY ANALYSIS
====================================================================================================

[1] Commit: bea108b
    Date:    2026-04-20 14:29:30
    Author:  Justin Hall
    Message: Update Feitian ePass FIDO2 Authenticator USB support status
    Entries: 232 AAGUIDs

    📈 Changes from previous commit (97156d8):
       • Added:    0
       • Removed:  0
       • Modified: 1

       🔄 MODIFIED:
          • Feitian ePass FIDO2 Authenticator
            AAGUID: 833b721a-ff5f-4d00-bb2e-bdda3ec01e29
            - USB: 'No' → 'Yes'

[2] Commit: 97156d8
    Date:    2026-04-07 16:44:09  
    Author:  Justinha
    Message: Fix table syntax: remove blank line breaking FIDO2 vendor table
    Entries: 232 AAGUIDs

    📈 Changes from previous commit:
       • Added:    45
       • Removed:  0
       • Modified: 0

       ➕ ADDED:
          • WiSECURE AuthTron USB FIDO2 Authenticator
            AAGUID: 504d7149-4e4c-3841-4555-55445a677357
            Bio: Yes | USB: Yes | NFC: No | BLE: No
          • YubiKey 5 CCN Series with NFC
            AAGUID: 3aa78eb1-ddd8-46a8-a821-8f8ec57a7bd5
            Bio: No | USB: Yes | NFC: Yes | BLE: No
          ... (43 more)

====================================================================================================
📈 SUMMARY STATISTICS
====================================================================================================
Total commits analyzed:     5
Date range:                 2026-04-06 to 2026-04-27
Current AAGUIDs:            232
Net change:                 +4520aa-4afe-b6f4-7e5e916b6d98
            - USB: 'Yes' → 'No'
            - NFC: 'No' → 'Yes'
          • Arculus FIDO2/U2F Key Card
            AAGUID: 9d3df6ba-282f-11ed-a261-0242ac120002
            - USB: 'Yes' → 'No'
            - NFC: 'No' → 'Yes'

====================================================================================================
📈 SUMMARY STATISTICS
====================================================================================================
Total commits analyzed:     3
Date range:                 2026-04-23 to 2026-05-05
Current AAGUIDs:            232
Oldest commit AAGUIDs:      232
Net change:                 0
```

## What It Detects

The script tracks changes to:

- **Description** - The name/description of the FIDO key
- **AAGUID** - The unique identifier (UUID format)
- **Bio** - Biometric support (Yes/No)
- **USB** - USB support (Yes/No)
- **NFC** - NFC support (Yes/No)
- **BLE** - Bluetooth Low Energy support (Yes/No)

## Change Types

- **➕ Added** - New AAGUIDs that appeared in this commit
- **➖ Removed** - AAGUIDs that were removed in this commit
- **Monthly reports**: `Show-FIDOCommitHistory -CurrentMonth` in monthly automation
- **Historical analysis**: Review specific months with `-Month` and `-Year`
- Scheduled with Windows Task Scheduler or cron
- Integrated into CI/CD pipelines
- Used to generate change notifications

### Example: Monthly Report Automation
AsChangeLog -OutputFile "Reports/FIDO-$(Get-Date -Format 'yyyy-MM').md"
# Export or email the results
```

## Changelog Format

When using `-AsChangeLog`, the output is formatted as professional markdown suitable for documentation:

- ✅ Clean markdown formatting (no emojis or color codes)
- 📋 Structured sections: Summary, Added, Removed, Modified
- 📊 Statistics table at the end
- 🔗 Links to source documentation
- 💾 Can be saved to file or piped to other commands

### Example Changelog Output

```markdown
# FIDO2 Hardware Vendor Changes - April 2026

Generated: 2026-05-12 07:37:41
Source: [Microsoft Docs FIDO2 Vendor Page](https://learn.microsoft.com...)

---

## 2026-04-20 - Commit bea108b

**Author:** Justin Hall
**Total AAGUIDs:** 232

### Summary

- **Modified:** 1 authenticator(s)

### Modified Authenticators

#### Feitian ePass FIDO2 Authenticator

- **AAGUID:** `833b721a-ff5f-4d00-bb2e-bdda3ec01e29`
- **Changes:**
  - USB: 'No' → 'Yes'

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Commits Analyzed | 5 |
| Date Range | 2026-04-06 to 2026-04-27 |
| Current Total AAGUIDs | 232 |
| Net Change | +45 |
# Generate a monthly report on the 1st of each month
$report = Show-FIDOCommitHistory -CurrentMonth -ShowDetails
# Export or email the results
```

The script uses the GitHub API which has rate limits:
- **Unauthenticated**: 60 requests per hour
- **Authenticated**: 5,000 requests per hour

If you hit the rate limit, wait a few minutes and try again.

## Integration

This script can be:
- Run manually to check for recent changes
- Scheduled with Windows Task Scheduler or cron
- Integrated into CI/CD pipelines
- Used to generate change notifications

## See Also

- [Merge-GHFidoData.ps1](./Merge-GHFidoData.ps1) - Main merge script
- [Export-GHEntraFido.ps1](./Export-GHEntraFido.ps1) - Extract FIDO data from URL
- [Microsoft Docs FIDO Vendor Page](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor)
