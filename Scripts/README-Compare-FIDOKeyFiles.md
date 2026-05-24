# Compare-FIDOKeyFiles

Compare two FIDO key JSON files and show what changed between them.

## Overview

The `Compare-FIDOKeyFiles` function compares two JSON files containing FIDO key data to identify:
- ➕ **Added** authenticators (AAGUIDs present in current but not in old)
- ➖ **Removed** authenticators (AAGUIDs present in old but not in current)
- 🔄 **Modified** authenticators (AAGUIDs present in both but with different properties)

This is useful for:
- Creating changelogs from backups
- Tracking changes over time
- Documenting database updates
- Auditing data modifications

## Syntax

```powershell
Compare-FIDOKeyFiles 
    -OldFile <String>
    [-CurrentFile <String>]
    [-ShowDetails]
    [-AsChangeLog]
    [-OutputFile <String>]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `OldFile` | String | Yes | - | Path to the older JSON file to compare from |
| `CurrentFile` | String | No | `Assets/FidoKeys.json` | Path to the current/newer JSON file to compare to |
| `ShowDetails` | Switch | No | False | Display detailed change information for each AAGUID |
| `AsChangeLog` | Switch | No | False | Format output as a professional changelog suitable for documentation |
| `OutputFile` | String | No | - | Save changelog output to a file (only valid with `-AsChangeLog`) |

## Examples

### Example 1: Basic Comparison
```powershell
# Compare a backup file with the current database
. ./Scripts/Compare-FIDOKeyFiles.ps1
Compare-FIDOKeyFiles -OldFile "backup/FidoKeys-2026-01-01.json"
```

**Output:**
```
📂 Loading JSON files...
   Old file:     FidoKeys-2026-01-01.json - 187 AAGUIDs
   Current file: FidoKeys.json - 232 AAGUIDs
🔍 Analyzing differences...

===============================================================================
📊 COMPARISON RESULTS
===============================================================================

📈 Summary:
   • Added:    45
   • Removed:  0
   • Modified: 3
   • Total:    48 changes

===============================================================================
📈 STATISTICS
===============================================================================
Old file AAGUIDs:     187
Current file AAGUIDs: 232
Net change:           45
Old file date:        2026-01-01 08:30:00
Current file date:    2026-05-06 00:44:17
```

### Example 2: Detailed Comparison
```powershell
# Show detailed information for each change
Compare-FIDOKeyFiles -OldFile "backup/FidoKeys-2026-01-01.json" -ShowDetails
```

**Output:**
```
📈 Summary:
   • Added:    45
   • Removed:  0
   • Modified: 3
   • Total:    48 changes

➕ ADDED (45):
   • Yubico YubiKey 5Ci FIPS
     AAGUID: c5ef55ff-ad9a-4b9f-b580-adebafe026d0
     Vendor: Yubico
     Bio: No | USB: Yes | NFC: Yes | BLE: No
   • Google Titan Security Key v2
     AAGUID: ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4
     Vendor: Google
     Bio: No | USB: Yes | NFC: Yes | BLE: No
   ...

🔄 MODIFIED (3):
   • Feitian BioPass FIDO2
     AAGUID: 12ded745-4bed-47d4-abaa-e713f51d6393
     Vendor: Feitian
     - ValidVendor: 'false' → 'true'
   ...
```

### Example 3: Generate Changelog
```powershell
# Generate a professional changelog and save to file
Compare-FIDOKeyFiles -OldFile "backup/FidoKeys-2026-01-01.json" `
                     -AsChangeLog `
                     -OutputFile "CHANGELOG-Jan-May-2026.md"
```

**Output:**
```
✅ Changelog saved to: CHANGELOG-Jan-May-2026.md
```

**Generated File Content:**
```markdown
# Changelog

## Comparison Results

45 new authenticators added, 3 authenticators updated between FidoKeys-2026-01-01.json and FidoKeys.json!

- **45 new authenticators have** been added to the supported vendors list
- **3 authenticators have** been updated with new capability information

## ✅ New Authenticators (45)

The following authenticators are now supported:

### Yubico YubiKey 5Ci FIPS

**AAGUID:** `c5ef55ff-ad9a-4b9f-b580-adebafe026d0`

**Supported Interfaces:**

| Interface | Supported |
|-----------|-----------|
| Biometric | ❌ |
| USB | ✅ |
| NFC | ✅ |
| BLE | ❌ |

### Google Titan Security Key v2

**AAGUID:** `ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4`

**Supported Interfaces:**

| Interface | Supported |
|-----------|-----------|
| Biometric | ❌ |
| USB | ✅ |
| NFC | ✅ |
| BLE | ❌ |

...

## ⚠️  Updated Authenticators (3)

The following authenticators have been updated with new capability information:

### Feitian BioPass FIDO2

**AAGUID:** `12ded745-4bed-47d4-abaa-e713f51d6393`

**Changes:**

- USB: ❌ → ✅
- Bio: ✅ → ❌

...
```

### Example 4: Compare Two Specific Files
```powershell
# Compare any two JSON files explicitly
Compare-FIDOKeyFiles -OldFile "Assets/FidoKeys-2026-04-01.json" `
                     -CurrentFile "Assets/FidoKeys-2026-05-01.json" `
                     -ShowDetails
```

### Example 5: Compare with Backup and Generate Report
```powershell
# Create a backup, make changes, then compare
cp Assets/FidoKeys.json Assets/FidoKeys.json.bak

# ... make some changes to FidoKeys.json ...

Compare-FIDOKeyFiles -OldFile "Assets/FidoKeys.json.bak" `
                     -CurrentFile "Assets/FidoKeys.json" `
                     -AsChangeLog `
                     -OutputFile "MY-CHANGES.md"
```

## Output Formats

### Console Format (Default)
- Colorful output with emojis
- Summary statistics
- Optional detailed listings (with `-ShowDetails`)
- Perfect for interactive terminal use

### Changelog Format (`-AsChangeLog`)
- Clean markdown matching the repository's CHANGELOG.md format
- Uses ✅ for "New Authenticators", ⚠️ for "Updated Authenticators", ❌ for "Removed Authenticators"
- Interface tables for new authenticators (Biometric, USB, NFC, BLE)
- Property change format: `USB: ❌ → ✅`
- Professional documentation style
- Ready to commit to version control or append to CHANGELOG.md

## Comparison Logic

The function compares FIDO keys by:

1. **AAGUID Matching**: Primary key for identifying authenticators
2. **Property Comparison**: For matching AAGUIDs, compares:
   - `Description`
   - `Vendor`
   - `Bio` (biometric support)
   - `USB` (USB connectivity)
   - `NFC` (NFC connectivity)
   - `BLE` (Bluetooth Low Energy)
   - `ValidVendor` (validation status)

## Use Cases

### 1. Pre-Merge Change Review
```powershell
# Before merging new data, see what will change
cp Assets/FidoKeys.json Assets/FidoKeys-before-merge.json
# ... run your merge script ...
Compare-FIDOKeyFiles -OldFile "Assets/FidoKeys-before-merge.json" -ShowDetails
```

### 2. Monthly Change Reports
```powershell
# Generate monthly changelog
Compare-FIDOKeyFiles -OldFile "backups/FidoKeys-$(Get-Date -Month ((Get-Date).Month-1) -Format 'yyyy-MM-01').json" `
                     -AsChangeLog `
                     -OutputFile "changelogs/CHANGELOG-$(Get-Date -Format 'yyyy-MM').md"
```

### 3. Audit Trail
```powershell
# Document all changes made during a session
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
cp Assets/FidoKeys.json "audit/before-$timestamp.json"
# ... make changes ...
Compare-FIDOKeyFiles -OldFile "audit/before-$timestamp.json" `
                     -AsChangeLog `
                     -OutputFile "audit/changes-$timestamp.md"
```

### 4. Data Integrity Check
```powershell
# Verify no unexpected changes occurred
Compare-FIDOKeyFiles -OldFile "validated/FidoKeys-known-good.json"
# If no changes shown, data integrity is preserved
```

## Related Scripts

- **Show-FIDOCommitHistory.ps1**: Compare changes across GitHub commits in Microsoft Docs
- **Sync-FidoKeysWithDocs.ps1**: Interactive sync with Microsoft Docs (has Compare-Databases function)
- **Merge-GHFidoData.ps1**: Merge URL data with local JSON (compares and logs changes)

## Notes

- Both JSON files must have the same structure (metadata and keys array)
- Date comparison uses `databaseLastUpdated` from metadata if available, otherwise file modification time
- The `-AsChangeLog` format matches the style of the repository's main CHANGELOG.md file
- New authenticators show interface support tables (Biometric, USB, NFC, BLE with ✅/❌)
- Updated authenticators show property changes in the format: `Property: ❌ → ✅`
- If both files are identical (same AAGUIDs, same properties), you'll see "No changes detected"
- Values are automatically converted: "Yes" → ✅, "No" → ❌

## Author
**Created:** 2026-05-24  
**Tool:** GitHub Copilot
