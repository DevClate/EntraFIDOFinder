# Define the path to the PowerShell script to be tested
$scriptPath = "Functions/Public/Find-FIDOKey.ps1"

# Import the function from the script
. $scriptPath

Describe "Find-FIDOKey" {
    # Test case: Check if the function filters by Brand
    Context "When filtering by Brand" {
        It "Should return only Yubico keys" {
            $result = Find-FIDOKey -Brand "Yubico"
            Write-Host "Result: $($result | ConvertTo-Json -Depth 3)"
            $result.Devices | Should -Not -BeNullOrEmpty
            $result.Devices | ForEach-Object {
                Write-Host "Device: $($_ | ConvertTo-Json -Depth 3)"
                $_.Vendor | Should -Be "Yubico"
            }
        }

        It "Should return only Feitian keys" {
            $result = Find-FIDOKey -Brand "Feitian"
            Write-Host "Result: $($result | ConvertTo-Json -Depth 3)"
            $result.Devices | Should -Not -BeNullOrEmpty
            $result.Devices | ForEach-Object {
                Write-Host "Device: $($_ | ConvertTo-Json -Depth 3)"
                $_.Vendor | Should -Be "Feitian"
            }
        }
    }

    # Test case: Check if the function filters by Type
    Context "When filtering by Type" {
        It "Should return only Bio keys" {
            $result = Find-FIDOKey -Type "Bio"
            Write-Host "Result: $($result | ConvertTo-Json -Depth 3)"
            $result.Devices | Should -Not -BeNullOrEmpty
            $result.Devices | ForEach-Object {
                Write-Host "Device: $($_ | ConvertTo-Json -Depth 3)"
                $_.Bio | Should -Be "Yes"
            }
        }

        It "Should return only USB keys" {
            $result = Find-FIDOKey -Type "USB"
            Write-Host "Result: $($result | ConvertTo-Json -Depth 3)"
            $result.Devices | Should -Not -BeNullOrEmpty
            $result.Devices | ForEach-Object {
                Write-Host "Device: $($_ | ConvertTo-Json -Depth 3)"
                $_.USB | Should -Be "Yes"
            }
        }
    }
}