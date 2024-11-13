Function Export-GHEntraFido {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    # Fetch the webpage content
    $response = Invoke-WebRequest -Uri $Url
    $htmlContent = $response.Content

    # Load the HTML content into an HtmlDocument object
    $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
    $htmlDocument.LoadHtml($htmlContent)

    # Extract all table nodes from the HTML document
    $tableNodes = $htmlDocument.DocumentNode.SelectNodes("//table")

    # Find the target table based on headers
    $targetTableNode = $null
    foreach ($tableNode in $tableNodes) {
        $headers = $tableNode.SelectNodes(".//thead/tr/th") | ForEach-Object { $_.InnerText.Trim() }
        if ($headers -contains "Description" -and $headers -contains "AAGUID") {
            $targetTableNode = $tableNode
            break
        }
    }

    if ($null -ne $targetTableNode) {
        # Extract headers from the target table
        $headers = $targetTableNode.SelectNodes(".//thead/tr/th") | ForEach-Object { $_.InnerText.Trim() }

        # Initialize an array to hold the data
        $data = @()

        # Process the rows of the target table
        $rowNodes = $targetTableNode.SelectNodes(".//tbody/tr")
        foreach ($rowNode in $rowNodes) {
            $cellNodes = $rowNode.SelectNodes("td")
            $row = @{
                Description = ""
                AAGUID = ""
                Bio = ""
                USB = ""
                NFC = ""
                BLE = ""
                Vendor = ""
            }

            for ($i = 0; $i -lt $cellNodes.Count; $i++) {
                $header = $headers[$i]
                $cell = $cellNodes[$i]
                $value = $cell.InnerText.Trim()

                if ($header -in @("Bio", "USB", "BLE", "NFC")) {
                    $urlValue = $null
                    if ($cell.SelectSingleNode(".//a")) {
                        $urlValue = $cell.SelectSingleNode(".//a").GetAttributeValue("href", "")
                    } elseif ($cell.SelectSingleNode(".//img")) {
                        $urlValue = $cell.SelectSingleNode(".//img").GetAttributeValue("src", "")
                    }

                    if ($urlValue -match "(yes|no)\.png$") {
                        $value = $matches[1] -replace "yes", "Yes" -replace "no", "No"
                    }
                }

                $row[$header] = $value
            }

            $data += [PSCustomObject]$row
        }

        # Output the data in the specified order
        $data | Select-Object Description, AAGUID, Bio, USB, NFC, BLE, Vendor
    } else {
        Write-Error "No table found with the specified headers."
    }
}