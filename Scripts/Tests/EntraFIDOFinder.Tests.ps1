BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../EntraFIDOFinder.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Find-FIDOKey filtering' {
    BeforeEach {
        Mock -ModuleName EntraFIDOFinder Get-Content {
            @'
{
  "metadata": { "databaseLastUpdated": "2026-11-20 11:03:27" },
  "keys": [
    { "Vendor": "New Vendor", "Description": "First", "AAGUID": "first", "Bio": "✅", "USB": "✅", "NFC": "❌", "BLE": "❌" },
    { "Vendor": "New Vendor", "Description": "Second", "AAGUID": "second", "Bio": "No", "USB": "Yes", "NFC": "Yes", "BLE": "No" },
    { "Vendor": "Other", "Description": "Third", "AAGUID": "third", "Bio": "❌", "USB": "❌", "NFC": "✅", "BLE": "✅" }
  ]
}
'@
        }
    }

    It 'filters both current and legacy capability values' {
        @(Find-FIDOKey -Type USB).AAGUID | Should -Be @('first', 'second')
        @(Find-FIDOKey -Type Bio).AAGUID | Should -Be @('first')
    }

    It 'applies multiple capability modes' {
        @(Find-FIDOKey -Type USB, NFC -TypeFilterMode All).AAGUID | Should -Be @('second')
        @(Find-FIDOKey -Type Bio, USB, NFC -TypeFilterMode AtLeastTwo).AAGUID | Should -Be @('first', 'second')
        @(Find-FIDOKey -Type Bio, USB, NFC -TypeFilterMode AtLeastThree).Count | Should -Be 0
    }

    It 'accepts database vendors and rejects unknown brands' {
        @(Find-FIDOKey -Brand 'New Vendor').Count | Should -Be 2
        { Find-FIDOKey -Brand 'Not a Vendor' -ErrorAction Stop } | Should -Throw '*Unknown brand*'
    }

    It 'preserves pipeline AAGUID filtering' {
        @('first', 'third' | Find-FIDOKey).AAGUID | Should -Be @('first', 'third')
    }
}

Describe 'Find-FIDOKey brand completion' {
    It 'offers vendors from the bundled database' {
        $inputText = 'Find-FIDOKey -Brand Web'
        $completions = TabExpansion2 -inputScript $inputText -cursorColumn $inputText.Length
        $completions.CompletionMatches.ListItemText | Should -Contain 'WebComm'
    }
}

Describe 'Show-FIDODbVersion' {
    BeforeEach {
        $localPath = Join-Path $TestDrive 'FidoKeys.json'
        '{"metadata":{"databaseLastUpdated":"2026-11-20 11:03:27"}}' | Set-Content $localPath
    }

    It 'reports when the local database is newer' {
        Mock -ModuleName EntraFIDOFinder Invoke-RestMethod {
            [PSCustomObject]@{ metadata = @{ databaseLastUpdated = '2026-11-19 11:03:27' } }
        }
        Show-FIDODbVersion -JsonFilePath $localPath | Should -Contain 'Your local database is newer than the latest database, which was last updated on: 2026-11-19 11:03:27'
    }

    It 'reports when the remote database is newer' {
        Mock -ModuleName EntraFIDOFinder Invoke-RestMethod {
            [PSCustomObject]@{ metadata = @{ databaseLastUpdated = '2026-11-21 11:03:27' } }
        }
        Show-FIDODbVersion -JsonFilePath $localPath | Should -Contain 'A newer version of the database is available. The latest database was last updated on: 2026-11-21 11:03:27'
    }

    It 'reports when the databases are the same' {
        Mock -ModuleName EntraFIDOFinder Invoke-RestMethod {
            [PSCustomObject]@{ metadata = @{ databaseLastUpdated = '2026-11-20 11:03:27' } }
        }
        Show-FIDODbVersion -JsonFilePath $localPath | Should -Contain 'Your local database is up to date.'
    }
}

Describe 'Get-FIDODbLog' {
    It 'returns pipeline-friendly log objects' {
        Mock -ModuleName EntraFIDOFinder Invoke-RestMethod {
            "# Merge Log - 2026-11-20 11:03:27`nUpdated a key`n"
        }
        $entry = Get-FIDODbLog
        $entry.Date | Should -Be '2026-11-20 11:03:27'
        $entry.Entry | Should -Be 'Updated a key'
    }

    It 'reports download failures as errors' {
        Mock -ModuleName EntraFIDOFinder Invoke-RestMethod { throw 'download failed' }
        { Get-FIDODbLog -ErrorAction Stop } | Should -Throw '*download failed*'
    }
}
