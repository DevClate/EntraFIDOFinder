    <#
    .SYNOPSIS
    Fetches and processes FIDO2 hardware vendor data from a specified URL.

    .DESCRIPTION
    This function fetches the webpage content from the specified URL, parses the HTML to find the table with headers "Description" and "AAGUID",
    and processes the rows to extract data. It ensures the table order is "Description", "AAGUID", "Bio", "USB", "NFC", "BLE" and outputs the data
    as an object for easy use in the pipeline.

    .PARAMETER Url
    The URL of the webpage to fetch the FIDO2 hardware vendor data from.

    .EXAMPLE
    $data = Export-EntraFido -Url "https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor"
    $data | Format-Table

    .EXAMPLE
    Export-EntraFido -Url "https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor" | Export-Csv -Path "FidoData.csv" -NoTypeInformation
    #>
function Export-EntraFido {
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
        $data | Select-Object Description, AAGUID, Bio, USB, NFC, BLE
    } else {
        Write-Error "No table found with the specified headers."
    }
}