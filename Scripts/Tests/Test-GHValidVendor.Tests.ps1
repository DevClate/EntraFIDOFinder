BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Test-GHValidVendor.ps1')

    function Invoke-Vendor {
        param([string]$Vendor, [string]$Description = 'Some Key', [string[]]$ValidVendors = @('Yubico', 'Feitian', 'HID'), [bool]$IsNew = $false, [string[]]$Existing = @())
        $ctx = @{
            Vendor   = [ref]$Vendor
            Changes  = [ref]$false
            Markdown = [System.Collections.ArrayList]::new()
            Detailed = [System.Collections.ArrayList]::new()
            Logged   = [System.Collections.ArrayList]::new()
            Issues   = [System.Collections.ArrayList]::new()
            Current  = [System.Collections.ArrayList]::new()
        }
        $out = Test-GHValidVendor -vendor $ctx.Vendor -description $Description -aaguid 'aaguid-1' -ValidVendors $ValidVendors `
            -markdownContent $ctx.Markdown -detailedLogContent $ctx.Detailed -loggedInvalidVendors $ctx.Logged -issueEntries $ctx.Issues `
            -existingLogEntries $Existing -changesDetected $ctx.Changes -IsNewEntry $IsNew -currentLogEntries $ctx.Current 6>$null
        $ctx.Out = $out
        $ctx
    }
}

Describe 'Test-GHValidVendor' {
    It 'returns only "Yes" for a valid vendor and changes nothing' {
        $c = Invoke-Vendor -Vendor 'Yubico'
        $c.Out | Should -Be 'Yes'
        $c.Changes.Value | Should -BeFalse
    }

    It 'corrects the vendor from the first word of the description' {
        $c = Invoke-Vendor -Vendor 'Bogus' -Description 'Feitian ePass'
        $c.Out | Should -Be 'Yes'
        $c.Vendor.Value | Should -Be 'Feitian'
        $c.Changes.Value | Should -BeTrue
        $c.Current[0] | Should -Be "Vendor corrected for AAGUID 'aaguid-1': 'Bogus' to 'Feitian'."
    }

    It 'maps a Yubikey first word to Yubico' {
        $c = Invoke-Vendor -Vendor 'Bogus' -Description 'YubiKey 5 NFC'
        $c.Out | Should -Be 'Yes'
        $c.Vendor.Value | Should -Be 'Yubico'
    }

    It 'finds a valid vendor elsewhere in the description' {
        $c = Invoke-Vendor -Vendor 'Bogus' -Description 'Token by HID Global'
        $c.Out | Should -Be 'Yes'
        $c.Vendor.Value | Should -Be 'HID'
        $c.Current[0] | Should -Match "^Vendor updated for AAGUID 'aaguid-1': 'Bogus' to 'HID' from description match\.$"
    }

    It 'returns "No" without logging for an existing entry with an invalid vendor' {
        $c = Invoke-Vendor -Vendor 'Bogus' -Description 'Nothing useful'
        $c.Out | Should -Be 'No'
        $c.Issues.Count | Should -Be 0
        $c.Changes.Value | Should -BeFalse
    }

    It 'logs an issue once for a new entry with an invalid vendor' {
        $c = Invoke-Vendor -Vendor 'Bogus' -Description 'Nothing useful' -IsNew $true
        $c.Out | Should -Be 'No'
        $c.Issues.Count | Should -Be 1
        $c.Issues[0] | Should -Be "Invalid Vendor Detected for AAGUID aaguid-1 : Bogus|Invalid vendor detected for AAGUID 'aaguid-1' with description 'Nothing useful'. Vendor 'Bogus' is not in the list of valid vendors.|InvalidVendor"
        $c.Markdown.Count | Should -Be 1
        $c.Changes.Value | Should -BeTrue
    }

    It 'does not re-log a new entry already present in existing log entries' {
        $entry = "Invalid vendor detected for AAGUID 'aaguid-1' with description 'Nothing useful'. Vendor 'Bogus' is not in the list of valid vendors."
        $c = Invoke-Vendor -Vendor 'Bogus' -Description 'Nothing useful' -IsNew $true -Existing @($entry)
        $c.Out | Should -Be 'No'
        $c.Issues.Count | Should -Be 0
    }

    It 'derives an empty vendor from the first word of the description' {
        $c = Invoke-Vendor -Vendor '' -Description 'Feitian BioPass'
        $c.Out | Should -Be 'Yes'
        $c.Vendor.Value | Should -Be 'Feitian'
        $c.Current[0] | Should -Be "Vendor set for AAGUID 'aaguid-1': '' to 'Feitian' (derived from description)."
    }

    It 'derives an empty vendor from a description match' {
        $c = Invoke-Vendor -Vendor '' -Description 'Token by HID Global'
        $c.Out | Should -Be 'Yes'
        $c.Vendor.Value | Should -Be 'HID'
        $c.Current[0] | Should -Be "Vendor derived for AAGUID 'aaguid-1': '' to 'HID' from description match."
    }

    It 'applies the Yubikey rule to an empty vendor' {
        $c = Invoke-Vendor -Vendor '' -Description 'YubiKey Bio'
        $c.Out | Should -Be 'Yes'
        $c.Vendor.Value | Should -Be 'Yubico'
    }

    It 'fails an empty vendor that cannot be derived and raises an issue for new entries' {
        $c = Invoke-Vendor -Vendor '' -Description 'Nothing useful' -IsNew $true
        $c.Out | Should -Be 'No'
        $c.Issues.Count | Should -Be 1
        $c.Issues[0] | Should -Match '^Empty Vendor Detected for AAGUID aaguid-1\|'
    }

    It 'treats vendor names literally when matching the description' {
        $c = Invoke-Vendor -Vendor 'Bogus' -Description 'Acme Co key' -ValidVendors @('A.me', 'Bad(')
        $c.Out | Should -Be 'No'
    }

    It 'accepts empty descriptions and null collections' {
        $v = [ref]'Bogus'
        $changes = [ref]$false
        $r = Test-GHValidVendor -vendor $v -description '' -aaguid 'x' -ValidVendors @('Yubico') -changesDetected $changes -IsNewEntry $true 6>$null
        $r | Should -Be 'No'
    }
}
