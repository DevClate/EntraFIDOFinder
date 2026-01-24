<#
.SYNOPSIS
Repairs corrupted ValidVendor values in FidoKeys.json

.DESCRIPTION
Fixes ValidVendor entries that have corrupted values like "17 18 8 Yes" 
and updates vendors for entries with "Unknown" vendor but valid vendor names in the description.
#>

function Repair-ValidVendor {
    param (
        [string]$JsonFilePath = "Assets/FidoKeys.json",
        [string]$ValidVendorsFilePath = "Assets/valid_vendors.json"
    )

    # Load the JSON data
    Write-Host "Loading JSON data from $JsonFilePath..."
    $jsonData = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json

    # Load valid vendors
    Write-Host "Loading valid vendors from $ValidVendorsFilePath..."
    $validVendorsData = Get-Content -Path $ValidVendorsFilePath -Raw | ConvertFrom-Json
    $ValidVendors = $validVendorsData.vendors

    $changesCount = 0

    foreach ($key in $jsonData.keys) {
        $changed = $false
        
        # Fix corrupted ValidVendor values (contains numbers)
        if ($key.ValidVendor -match '^\d+\s+\d+\s+\d+\s+(Yes|No)$') {
            $correctValue = if ($key.ValidVendor -match 'Yes$') { "Yes" } else { "No" }
            Write-Host "Fixing ValidVendor for AAGUID $($key.AAGUID): '$($key.ValidVendor)' -> '$correctValue'"
            $key.ValidVendor = $correctValue
            $changed = $true
        }

        # Fix Unknown vendors when description contains YubiKey (case-insensitive)
        if ($key.Vendor -eq "Unknown" -and $key.Description -imatch "^Yubikey") {
            Write-Host "Updating Vendor for AAGUID $($key.AAGUID): 'Unknown' -> 'Yubico' (Description: $($key.Description))"
            $key.Vendor = "Yubico"
            $key.ValidVendor = "Yes"
            $changed = $true
        }
        
        # Fix any other Unknown vendors where a valid vendor appears in the description
        if ($key.Vendor -eq "Unknown") {
            foreach ($validVendor in $ValidVendors) {
                if ($key.Description -match $validVendor) {
                    Write-Host "Updating Vendor for AAGUID $($key.AAGUID): 'Unknown' -> '$validVendor' (Description: $($key.Description))"
                    $key.Vendor = $validVendor
                    $key.ValidVendor = "Yes"
                    $changed = $true
                    break
                }
            }
        }

        if ($changed) {
            $changesCount++
        }
    }

    if ($changesCount -gt 0) {
        Write-Host "`nSaving changes to $JsonFilePath..."
        $jsonData | ConvertTo-Json -Depth 100 | Set-Content -Path $JsonFilePath
        Write-Host "Successfully repaired $changesCount entries."
    }
    else {
        Write-Host "No corrupted entries found."
    }
}

# Run the repair if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Repair-ValidVendor
}
