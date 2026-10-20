BeforeAll {
    if (-not ('HtmlAgilityPack.HtmlDocument' -as [type])) {
        $assemblyPath = $env:HTML_AGILITY_PACK_PATH
        if ([string]::IsNullOrWhiteSpace($assemblyPath) -or
            -not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) {
            throw 'Set HTML_AGILITY_PACK_PATH to HtmlAgilityPack.dll or load HtmlAgilityPack before running these tests.'
        }

        Add-Type -Path $assemblyPath -ErrorAction Stop
    }

    . (Join-Path $PSScriptRoot '..' 'Export-GHEntraFido.ps1')
}

Describe 'Export-GHEntraFido' {
    BeforeEach {
        $script:responseHtml = ''
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ Content = $script:responseHtml }
        }
    }

    It 'fetches once and returns normalized data in the stable output shape' {
        $script:responseHtml = @'
<table>
  <thead><tr>
    <th> Description </th><th>AAGUID</th><th>USB</th>
    <th>Biometric</th><th>NFC</th><th>BLE</th>
  </tr></thead>
  <tbody><tr>
    <td>Example &amp; Key</td><td>00000000-0000-0000-0000-000000000001</td>
    <td><img src="/images/yes.png" /></td><td><img alt="No" /></td>
    <td> Yes </td><td></td>
  </tr></tbody>
</table>
'@

        $result = @(Export-GHEntraFido -Url 'https://example.test/fido')

        $result | Should -HaveCount 1
        ($result[0].PSObject.Properties.Name -join ',') |
            Should -Be 'Description,AAGUID,Bio,USB,NFC,BLE,Vendor'
        $result[0].Description | Should -Be 'Example & Key'
        $result[0].AAGUID | Should -Be '00000000-0000-0000-0000-000000000001'
        $result[0].Bio | Should -Be 'No'
        $result[0].USB | Should -Be 'Yes'
        $result[0].NFC | Should -Be 'Yes'
        $result[0].BLE | Should -Be ''
        $result[0].Vendor | Should -Be ''
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }

    It 'matches required headers without depending on their order' {
        $script:responseHtml = @'
<table><thead><tr><th>AAGUID</th><th>Other</th><th>Description</th></tr></thead>
<tbody><tr><td>00000000-0000-0000-0000-000000000002</td><td>ignored</td><td>Reordered Key</td></tr></tbody></table>
'@

        $result = @(Export-GHEntraFido -Url 'https://example.test/fido')

        $result | Should -HaveCount 1
        $result[0].Description | Should -Be 'Reordered Key'
        $result[0].AAGUID | Should -Be '00000000-0000-0000-0000-000000000002'
    }

    It 'throws when the expected table is missing' {
        $script:responseHtml = '<table><thead><tr><th>Name</th><th>ID</th></tr></thead></table>'

        { Export-GHEntraFido -Url 'https://example.test/fido' } |
            Should -Throw '*No table with both Description and AAGUID headers*'
    }

    It 'throws when the response contains no HTML' {
        $script:responseHtml = ''

        { Export-GHEntraFido -Url 'https://example.test/fido' } |
            Should -Throw '*did not contain HTML content*'
    }

    It 'throws when the table has no data rows' {
        $script:responseHtml = '<table><thead><tr><th>Description</th><th>AAGUID</th></tr></thead><tbody></tbody></table>'

        { Export-GHEntraFido -Url 'https://example.test/fido' } |
            Should -Throw '*did not contain any data rows*'
    }

    It 'throws when a row cell count does not match the header count' {
        $script:responseHtml = @'
<table><thead><tr><th>Description</th><th>AAGUID</th></tr></thead>
<tbody><tr><td>Incomplete Key</td></tr></tbody></table>
'@

        { Export-GHEntraFido -Url 'https://example.test/fido' } |
    Should -Throw '*has 1 table cells for 2 header columns*'
    }

    It 'propagates web request failures as terminating errors' {
        Mock Invoke-WebRequest { throw 'network unavailable' }

        { Export-GHEntraFido -Url 'https://example.test/fido' } |
            Should -Throw '*network unavailable*'
    }
}
