function Export-GHEntraFido {
    <#
    .SYNOPSIS
    Exports FIDO data from a specified URL.

    .DESCRIPTION
    Fetches a webpage once, finds the table with Description and AAGUID columns,
    and returns normalized FIDO authenticator data. The expected properties are
    Description, AAGUID, Bio, USB, NFC, BLE, and Vendor. Missing required table
    structure or unusable rows produce terminating errors.

    .PARAMETER Url
    The URL of the webpage containing the FIDO data table.

    .PARAMETER HtmlAgilityPackPath
    Optional path to HtmlAgilityPack.dll when its assembly is not already loaded.

    .EXAMPLE
    Export-GHEntraFido -Url "https://example.com/fido-data"

    .EXAMPLE
    Export-GHEntraFido -Url "https://example.com/fido-data" -HtmlAgilityPackPath "./HtmlAgilityPack.dll"

    .OUTPUTS
    PSCustomObject with Description, AAGUID, Bio, USB, NFC, BLE, and Vendor properties.

    .NOTES
    The GitHub merge workflows load their pinned HtmlAgilityPack assembly before
    dot-sourcing this script. For standalone use, load the assembly first or pass
    -HtmlAgilityPackPath. Focused tests are in Scripts/Tests/Export-GHEntraFido.Tests.ps1;
    set HTML_AGILITY_PACK_PATH to HtmlAgilityPack.dll before running them with Invoke-Pester.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter()]
        [string]$HtmlAgilityPackPath
    )

    if (-not ('HtmlAgilityPack.HtmlDocument' -as [type])) {
        if ([string]::IsNullOrWhiteSpace($HtmlAgilityPackPath)) {
            throw "HtmlAgilityPack is not loaded. Load the assembly before calling this function or provide -HtmlAgilityPackPath."
        }

        if (-not (Test-Path -LiteralPath $HtmlAgilityPackPath -PathType Leaf)) {
            throw "HtmlAgilityPack.dll was not found at '$HtmlAgilityPackPath'."
        }

        try {
            Add-Type -Path (Resolve-Path -LiteralPath $HtmlAgilityPackPath).Path -ErrorAction Stop
        }
        catch {
            throw "Failed to load HtmlAgilityPack from '$HtmlAgilityPackPath': $($_.Exception.Message)"
        }
    }

    $response = Invoke-WebRequest -Uri $Url -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($response.Content)) {
        throw "The response from '$Url' did not contain HTML content."
    }

    $htmlDocument = [HtmlAgilityPack.HtmlDocument]::new()
    $htmlDocument.LoadHtml($response.Content)
    $tableNodes = $htmlDocument.DocumentNode.SelectNodes('//table')
    $targetTableNode = $null
    $headers = @()

    foreach ($tableNode in @($tableNodes)) {
        if ($null -eq $tableNode) {
            continue
        }

        $headerNodes = $tableNode.SelectNodes('./thead/tr[1]/th')
        if ($null -eq $headerNodes) {
            $headerNodes = $tableNode.SelectNodes('./tr[1]/th')
        }

        if ($null -eq $headerNodes) {
            continue
        }

        $candidateHeaders = @(
            foreach ($headerNode in $headerNodes) {
                [HtmlAgilityPack.HtmlEntity]::DeEntitize($headerNode.InnerText) -replace '\s+', ' '
            }
        ) | ForEach-Object { $_.Trim() }

        $normalizedHeaders = @(
            foreach ($header in $candidateHeaders) {
                switch -Regex ($header.Trim().ToLowerInvariant()) {
                    '^(description)$' { 'Description'; break }
                    '^(aaguid)$' { 'AAGUID'; break }
                    '^(bio|biometric)$' { 'Bio'; break }
                    '^(usb)$' { 'USB'; break }
                    '^(nfc)$' { 'NFC'; break }
                    '^(ble|bluetooth low energy)$' { 'BLE'; break }
                    default { $header.Trim() }
                }
            }
        )

        if ($normalizedHeaders -contains 'Description' -and $normalizedHeaders -contains 'AAGUID') {
            $targetTableNode = $tableNode
            $headers = $normalizedHeaders
            break
        }
    }

    if ($null -eq $targetTableNode) {
        throw "No table with both Description and AAGUID headers was found at '$Url'."
    }

    $capabilityHeaders = @('Bio', 'USB', 'NFC', 'BLE')
    $data = [System.Collections.Generic.List[object]]::new()
    $rowNodes = $targetTableNode.SelectNodes('./tbody/tr')

    foreach ($rowNode in @($rowNodes)) {
        if ($null -eq $rowNode) {
            continue
        }

        $cellNodes = $rowNode.SelectNodes('./td')
        if ($null -eq $cellNodes -or $cellNodes.Count -eq 0) {
            continue
        }

        if ($cellNodes.Count -ne $headers.Count) {
            throw "A row in the FIDO table at '$Url' has $($cellNodes.Count) table cells for $($headers.Count) header columns."
        }

        $row = [ordered]@{
            Description = ''
            AAGUID      = ''
            Bio         = ''
            USB         = ''
            NFC         = ''
            BLE         = ''
            Vendor      = ''
        }

        for ($index = 0; $index -lt [Math]::Min($cellNodes.Count, $headers.Count); $index++) {
            $header = $headers[$index]
            if (-not $row.Contains($header)) {
                continue
            }

            $cell = $cellNodes[$index]
            $value = [HtmlAgilityPack.HtmlEntity]::DeEntitize($cell.InnerText) -replace '\s+', ' '
            $value = $value.Trim()

            if ($header -in $capabilityHeaders) {
                $imageNode = $cell.SelectSingleNode('.//img')
                if ($null -ne $imageNode) {
                    $altText = [HtmlAgilityPack.HtmlEntity]::DeEntitize(
                        $imageNode.GetAttributeValue('alt', '')
                    ).Trim()
                    if ($altText -match '^(?i:yes|no)$') {
                        $value = $altText.Substring(0, 1).ToUpperInvariant() + $altText.Substring(1).ToLowerInvariant()
                    }
                    else {
                        $imageSource = $imageNode.GetAttributeValue('src', '')
                        $iconMatch = [regex]::Match($imageSource, '(?i)(?:^|/)(yes|no)\.png(?:[?#].*)?$')
                        if ($iconMatch.Success) {
                            $value = $iconMatch.Groups[1].Value.Substring(0, 1).ToUpperInvariant() +
                                $iconMatch.Groups[1].Value.Substring(1).ToLowerInvariant()
                        }
                    }
                }

                if ($value -notmatch '^(?i:yes|no)$') {
                    $linkNode = $cell.SelectSingleNode('.//a')
                    if ($null -ne $linkNode) {
                        $linkMatch = [regex]::Match(
                            $linkNode.GetAttributeValue('href', ''),
                            '(?i)(?:^|/)(yes|no)\.png(?:[?#].*)?$'
                        )
                        if ($linkMatch.Success) {
                            $value = $linkMatch.Groups[1].Value.Substring(0, 1).ToUpperInvariant() +
                                $linkMatch.Groups[1].Value.Substring(1).ToLowerInvariant()
                        }
                    }
                }
            }

            $row[$header] = $value
        }

        if ([string]::IsNullOrWhiteSpace($row.Description) -or [string]::IsNullOrWhiteSpace($row.AAGUID)) {
            throw "A row in the FIDO table at '$Url' has an empty Description or AAGUID."
        }

        $data.Add([PSCustomObject]$row)
    }

    if ($data.Count -eq 0) {
        throw "The FIDO table at '$Url' did not contain any data rows."
    }

    $data
}
