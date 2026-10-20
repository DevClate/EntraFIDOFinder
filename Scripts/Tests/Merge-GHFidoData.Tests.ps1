BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Test-GHValidVendor.ps1')
    . (Join-Path $PSScriptRoot '..' 'Test-GHAAGUIDExists.ps1')
    . (Join-Path $PSScriptRoot '..' 'Export-GHEntraFido.ps1')
    . (Join-Path $PSScriptRoot '..' 'Merge-GHFidoData.ps1')

    function New-FidoRow {
        param([string]$Description, [string]$AAGUID, [string]$USB = 'Yes')
        [PSCustomObject]@{
            Description = $Description; AAGUID = $AAGUID; Bio = 'No'; USB = $USB; NFC = 'No'; BLE = 'No'; Vendor = ''
        }
    }

    function New-FidoKey {
        param([string]$Vendor, [string]$Description, [string]$AAGUID, [string]$ValidVendor = 'Yes')
        [PSCustomObject]@{
            Vendor = $Vendor; Description = $Description; AAGUID = $AAGUID
            Bio = 'No'; USB = 'Yes'; NFC = 'No'; BLE = 'No'
            Version = 'FIDO 2.1'; ValidVendor = $ValidVendor
        }
    }

    function New-MergeFixture {
        param([object[]]$Keys)
        $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $dir | Out-Null
        $paths = @{
            Dir      = $dir
            Json     = Join-Path $dir 'FidoKeys.json'
            Vendors  = Join-Path $dir 'valid_vendors.json'
            Markdown = Join-Path $dir 'merge_log.md'
            Detailed = Join-Path $dir 'detailed_log.txt'
            Env      = Join-Path $dir 'env_vars.txt'
        }
        @{ vendors = @('Yubico', 'ACS') } | ConvertTo-Json | Set-Content $paths.Vendors
        @{
            metadata = @{ databaseLastChecked = '2020-01-01 00:00:00'; databaseLastUpdated = '2020-01-01 00:00:00' }
            keys     = @($Keys)
        } | ConvertTo-Json -Depth 10 | Set-Content $paths.Json
        $paths
    }

    function Invoke-Merge {
        param($Paths, [hashtable]$Extra = @{})
        Merge-GHFidoData -Url 'https://example.test' -JsonFilePath $Paths.Json -MarkdownFilePath $Paths.Markdown `
            -DetailedLogFilePath $Paths.Detailed -ValidVendorsFilePath $Paths.Vendors -EnvFilePath $Paths.Env @Extra 6>$null
    }

    function Get-FixtureKeys {
        param($Paths)
        (Get-Content -Raw $Paths.Json | ConvertFrom-Json).keys
    }

    function New-BaseKeys {
        1..10 | ForEach-Object {
            New-FidoKey -Vendor 'Yubico' -Description "Yubico Key $_" -AAGUID ('00000000-0000-0000-0000-{0:D12}' -f $_)
        }
    }

    function New-BaseRows {
        1..10 | ForEach-Object {
            New-FidoRow -Description "Yubico Key $_" -AAGUID ('00000000-0000-0000-0000-{0:D12}' -f $_)
        }
    }
}

Describe 'Merge-GHFidoData' {
    BeforeEach {
        $script:rows = @()
        Mock Export-GHEntraFido { $script:rows }
    }

    It 'leaves keys unchanged and logs a no-change run when the scrape matches' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $script:rows = New-BaseRows

        Invoke-Merge $paths

        $keys = @(Get-FixtureKeys $paths)
        $keys | Should -HaveCount 10
        ($keys.ValidVendor | Select-Object -Unique) | Should -Be 'Yes'
        Test-Path $paths.Markdown | Should -BeFalse
        Test-Path $paths.Env | Should -BeFalse
        Get-Content -Raw $paths.Detailed | Should -Match '(?m)^DETAILED LOG - \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        Get-Content -Raw $paths.Detailed | Should -Match 'No changes detected during this run\.'
        Test-Path "$($paths.Json).tmp" | Should -BeFalse
    }

    It 'updates changed properties and writes a merge log entry' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $script:rows = @(New-BaseRows)
        $script:rows[0].USB = 'No'

        Invoke-Merge $paths

        (Get-FixtureKeys $paths | Where-Object AAGUID -eq '00000000-0000-0000-0000-000000000001').USB | Should -Be 'No'
        $log = Get-Content -Raw $paths.Markdown
        $log | Should -Match '(?m)^# Merge Log - \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        $log | Should -Match "Updated 'USB' for AAGUID '00000000-0000-0000-0000-000000000001' from 'Yes' to 'No'\."
        Get-Content -Raw $paths.Detailed | Should -Match 'Updated ''USB'''
    }

    It 'adds a new entry with a valid vendor and stores ValidVendor as a plain string' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $script:rows = @(New-BaseRows) + (New-FidoRow -Description 'Yubico New Key' -AAGUID 'aaaaaaaa-0000-0000-0000-000000000001')

        Invoke-Merge $paths

        $keys = @(Get-FixtureKeys $paths)
        $keys | Should -HaveCount 11
        $new = $keys | Where-Object AAGUID -eq 'aaaaaaaa-0000-0000-0000-000000000001'
        $new.Vendor | Should -Be 'Yubico'
        $new.ValidVendor | Should -BeOfType [string]
        $new.ValidVendor | Should -Be 'Yes'
        Get-Content -Raw $paths.Markdown | Should -Match "Added new entry for AAGUID 'aaaaaaaa-0000-0000-0000-000000000001'"
    }

    It 'flags a new entry with an unknown vendor and writes an escaped ISSUE_ENTRIES line' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $script:rows = @(New-BaseRows) + (New-FidoRow -Description 'Zzzq Mystery Key' -AAGUID 'bbbbbbbb-0000-0000-0000-000000000001')

        Invoke-Merge $paths

        $new = Get-FixtureKeys $paths | Where-Object AAGUID -eq 'bbbbbbbb-0000-0000-0000-000000000001'
        $new.Vendor | Should -Be 'Unknown'
        $new.ValidVendor | Should -Be 'No'
        $envLines = @(Get-Content $paths.Env)
        $envLines | Should -HaveCount 1
        $envLines[0] | Should -Match '^ISSUE_ENTRIES=Empty Vendor Detected for AAGUID bbbbbbbb-0000-0000-0000-000000000001\|'
        $envLines[0] | Should -Match '%27'
        $envLines[0] | Should -Match '\|InvalidVendor$'
    }

    It 'persists a vendor correction and reports the key as newly valid' {
        $keys = @(New-BaseKeys)
        $keys[0].Vendor = 'Bogus'
        $keys[0].ValidVendor = 'No'
        $paths = New-MergeFixture -Keys $keys
        $script:rows = New-BaseRows

        Invoke-Merge $paths

        $fixed = Get-FixtureKeys $paths | Where-Object AAGUID -eq '00000000-0000-0000-0000-000000000001'
        $fixed.Vendor | Should -Be 'Yubico'
        $fixed.ValidVendor | Should -BeOfType [string]
        $fixed.ValidVendor | Should -Be 'Yes'
        Get-Content -Raw $paths.Env | Should -Match 'KEYS_NOW_VALID=00000000-0000-0000-0000-000000000001'
        Get-Content -Raw $paths.Markdown | Should -Match 'has become valid'
    }

    It 'removes keys that are gone from the source within the safety limit' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $script:rows = @(New-BaseRows | Select-Object -First 9)

        Invoke-Merge $paths

        @(Get-FixtureKeys $paths) | Should -HaveCount 9
        Get-Content -Raw $paths.Markdown | Should -Match "Entry removed for description 'Yubico Key 10'"
    }

    It 'does not touch any file when the scrape is empty' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $before = Get-Content -Raw $paths.Json
        $script:rows = @()

        { Invoke-Merge $paths } | Should -Throw '*No FIDO keys were found*'

        Get-Content -Raw $paths.Json | Should -Be $before
        Test-Path $paths.Markdown | Should -BeFalse
        Test-Path $paths.Detailed | Should -BeFalse
    }

    It 'refuses to remove more keys than the safety limit allows' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $before = Get-Content -Raw $paths.Json
        $script:rows = @(New-BaseRows | Select-Object -First 7)

        { Invoke-Merge $paths } | Should -Throw '*Refusing to remove 3 of 10*'

        Get-Content -Raw $paths.Json | Should -Be $before
        Test-Path $paths.Markdown | Should -BeFalse
    }

    It 'allows larger removals when the limit is raised' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $script:rows = @(New-BaseRows | Select-Object -First 7)

        Invoke-Merge $paths @{ MaxRemovalPercent = 50 }

        @(Get-FixtureKeys $paths) | Should -HaveCount 7
    }

    It 'keeps the first row when an AAGUID appears twice and warns' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        $script:rows = @(New-BaseRows) + (New-FidoRow -Description 'Yubico Duplicate' -AAGUID '00000000-0000-0000-0000-000000000001')

        Invoke-Merge $paths @{ WarningVariable = 'mergeWarnings'; WarningAction = 'SilentlyContinue' }

        $keys = @(Get-FixtureKeys $paths)
        $keys | Should -HaveCount 10
        ($keys | Where-Object AAGUID -eq '00000000-0000-0000-0000-000000000001').Description | Should -Be 'Yubico Key 1'
        ($keys | Where-Object AAGUID -eq '00000000-0000-0000-0000-000000000001').Description | Should -BeOfType [string]
    }

    It 'replaces a stale environment file instead of appending to it' {
        $paths = New-MergeFixture -Keys (New-BaseKeys)
        Set-Content $paths.Env 'ISSUE_ENTRIES=stale'
        $script:rows = New-BaseRows

        Invoke-Merge $paths

        Test-Path $paths.Env | Should -BeFalse
    }

    It 'writes keys as a JSON array even when only one key remains' {
        $paths = New-MergeFixture -Keys @(New-FidoKey -Vendor 'Yubico' -Description 'Yubico Key 1' -AAGUID '00000000-0000-0000-0000-000000000001')
        $script:rows = @(New-FidoRow -Description 'Yubico Key 1' -AAGUID '00000000-0000-0000-0000-000000000001')

        Invoke-Merge $paths

        (Get-Content -Raw $paths.Json | ConvertFrom-Json -NoEnumerate).keys.GetType().IsArray | Should -BeTrue
    }
}
