BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'Merge-GHFIDOMetaData.ps1'

    function New-Fixture {
        param($DbKeys, $MdsEntries)
        $db = [ordered]@{
            metadata = [ordered]@{ databaseLastUpdated = '2000-01-01 00:00:00'; databaseLastChecked = '2000-01-01 00:00:00' }
            keys     = $DbKeys
        }
        $dbPath = Join-Path $TestDrive 'FidoKeys.json'
        $db | ConvertTo-Json -Depth 100 | Set-Content -Path $dbPath -Encoding utf8
        $log = Join-Path $TestDrive 'log.txt'
        if (Test-Path $log) { Remove-Item $log }
        $mds = [PSCustomObject]@{ entries = $MdsEntries } | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        @{ Db = $dbPath; Log = $log; Mds = $mds }
    }

    function Invoke-Merge {
        param($Fixture)
        $null = & $script:ScriptPath -ExistingKeyFile $Fixture.Db -LogFilePath $Fixture.Log -MdsData $Fixture.Mds
        Get-Content $Fixture.Db -Raw | ConvertFrom-Json -Depth 100
    }

    function New-Ms {
        param($Algs = @('a', 'b'), $Extra, $Description = 'Key')
        $ms = [ordered]@{
            description = $Description
            authenticationAlgorithms = $Algs
            userVerificationDetails = @(, @([ordered]@{ userVerificationMethod = 'presence_internal' }))
            authenticatorGetInfo = [ordered]@{ versions = @('FIDO_2_1') }
        }
        if ($Extra) { foreach ($k in $Extra.Keys) { $ms[$k] = $Extra[$k] } }
        $ms
    }

    $script:Id = '11111111-1111-1111-1111-111111111111'
    function New-DbKey { param($Ms, $Time = '2024-01-01'); [ordered]@{ Vendor = 'V'; Description = 'D'; AAGUID = $script:Id; ValidVendor = 'Yes'; timeOfLastStatusChange = $Time; metadataStatement = $Ms } }
    function New-MdsEntry { param($Ms, $Time = '2024-01-01'); [ordered]@{ aaguid = $script:Id; timeOfLastStatusChange = $Time; metadataStatement = $Ms } }
}

Describe 'Merge-GHFIDOMetaData' {
    It 'makes no key changes and keeps the updated timestamp when data matches' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @(New-MdsEntry (New-Ms))
        $r = Invoke-Merge $f
        $r.metadata.databaseLastUpdated | Should -Be '2000-01-01 00:00:00'
        $r.metadata.databaseLastChecked | Should -Not -Be '2000-01-01 00:00:00'
        (Get-Content $f.Log -Raw) | Should -Match 'No changes have been detected since last run.'
    }

    It 'updates timeOfLastStatusChange, bumps databaseLastUpdated and logs it' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @(New-MdsEntry (New-Ms) -Time '2025-05-05')
        $r = Invoke-Merge $f
        $r.keys[0].timeOfLastStatusChange | Should -Be '2025-05-05'
        $r.metadata.databaseLastUpdated | Should -Not -Be '2000-01-01 00:00:00'
        $r.metadata.databaseLastUpdated | Should -Match '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$'
        (Get-Content $f.Log -Raw) | Should -Match 'Updating timeOfLastStatusChange'
        (Get-Content $f.Log -Raw) | Should -Match '===== Script Run on'
    }

    It 'detects same-length scalar array differences' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms -Algs @('a', 'b'))) -MdsEntries @(New-MdsEntry (New-Ms -Algs @('a', 'c')))
        $r = Invoke-Merge $f
        $r.keys[0].metadataStatement.authenticationAlgorithms | Should -Be @('a', 'c')
    }

    It 'adds properties that only exist upstream' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @(New-MdsEntry (New-Ms -Extra @{ cryptoStrength = 128 }))
        $r = Invoke-Merge $f
        $r.keys[0].metadataStatement.cryptoStrength | Should -Be 128
    }

    It 'removes properties deleted upstream' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms -Extra @{ cryptoStrength = 128 })) -MdsEntries @(New-MdsEntry (New-Ms))
        $r = Invoke-Merge $f
        $r.keys[0].metadataStatement.PSObject.Properties.Name | Should -Not -Contain 'cryptoStrength'
    }

    It 'updates scalar values and nested object arrays' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms -Description 'Old')) -MdsEntries @(New-MdsEntry (New-Ms -Description 'New'))
        $r = Invoke-Merge $f
        $r.keys[0].metadataStatement.description | Should -Be 'New'
        (Get-Content $f.Log -Raw) | Should -Match 'Updating AAGUID .* : description : "Old" -> "New"'
    }

    It 'keeps versions as an array and normalizes them' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @(New-MdsEntry (New-Ms))
        $r = Invoke-Merge $f
        , $r.keys[0].metadataStatement.authenticatorGetInfo.versions | Should -BeOfType [object[]]
        $r.keys[0].metadataStatement.authenticatorGetInfo.versions | Should -Be 'FIDO 2.1'
    }

    It 'adds metadataStatement when the local key has none' {
        $k = New-DbKey (New-Ms); $k.Remove('metadataStatement')
        $f = New-Fixture -DbKeys @($k) -MdsEntries @(New-MdsEntry (New-Ms))
        $r = Invoke-Merge $f
        $r.keys[0].metadataStatement.description | Should -Be 'Key'
        (Get-Content $f.Log -Raw) | Should -Match 'Adding metadataStatement from FAAA to EXXX entry'
    }

    It 'aborts without touching files when MDS has no entries' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @()
        $before = Get-Content $f.Db -Raw
        { & $script:ScriptPath -ExistingKeyFile $f.Db -LogFilePath $f.Log -MdsData $f.Mds } | Should -Throw '*no entries*'
        Get-Content $f.Db -Raw | Should -Be $before
        Test-Path $f.Log | Should -BeFalse
    }

    It 'aborts when no existing AAGUID matches MDS' {
        $other = New-MdsEntry (New-Ms); $other.aaguid = '22222222-2222-2222-2222-222222222222'
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @($other)
        $before = Get-Content $f.Db -Raw
        { & $script:ScriptPath -ExistingKeyFile $f.Db -LogFilePath $f.Log -MdsData $f.Mds } | Should -Throw '*None of the existing AAGUIDs*'
        Get-Content $f.Db -Raw | Should -Be $before
    }

    It 'uses the first MDS entry when AAGUIDs are duplicated' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @((New-MdsEntry (New-Ms) -Time '2025-01-01'), (New-MdsEntry (New-Ms) -Time '2026-01-01'))
        $r = Invoke-Merge $f
        $r.keys[0].timeOfLastStatusChange | Should -Be '2025-01-01'
    }

    It 'writes GitHub outputs and leaves no temp file' {
        $f = New-Fixture -DbKeys @(New-DbKey (New-Ms)) -MdsEntries @(New-MdsEntry (New-Ms) -Time '2025-05-05')
        $out = Join-Path $TestDrive 'gh_output.txt'
        $env:GITHUB_OUTPUT = $out
        try { $null = Invoke-Merge $f } finally { Remove-Item Env:GITHUB_OUTPUT }
        $text = Get-Content $out -Raw
        $text | Should -Match 'existingKeyCount=1'
        $text | Should -Match 'FIDOAKeyCount=1'
        $text | Should -Match 'changesMade=True'
        Test-Path "$($f.Db).tmp" | Should -BeFalse
    }
}
