# EntraFIDOFinder ![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/EntraFIDOFinder?label=Downloads&style=flat-square) [![Platform](https://img.shields.io/badge/platform-Windows%20/%20Linux%20/%20Mac-blue)](https://github.com/DevClate/EntraFIDOFinder) [![Maintenance](https://img.shields.io/maintenance/yes/2024)](https://github.com/DevClate/EntraFIDOFinder)


PowerShell Module to find compatible attestation FIDO2 keys for Entra.

**Database Last Updated:** 2024-12-02

Here are some cmdlets to get you started:

```powershell
# Find all compatible keys
Find-FIDOKey

# Find all Yubico keys
Find-FIDOKey -Brand Yubico

# Find all Yubico and OneSpan
Find-FIDOKey -Brand Yubico,Onespan

# Find keys that have both USB and NFC
Find-FIDOKey -Type USB,NFC -TypeFilterMode AtLeastTwo

# Find keys that have either USB or NFC
Find-FIDOKey -Type USB,NFC

# Find keys that are FIDO 2.1
Find-FIDOKey -FIDOVersion "FIDO 2.1"

# Find keys that are FIDO 2.1 with all properties in JSON output
Find-FIDOKey -FIDOVersion "FIDO 2.1" -AllProperties

# Here is an example showing the standard with Protocol Family
Find-FIDOKey -DetailedProperties | Select-Object Vendor, Description, @{Name="ProtocolFamily";Expression={$_.metadataStatement.protocolFamily}} | fl

# Find information on a single AAGUID
"50a45b0c-80e7-f944-bf29-f552bfa2e048" | Find-FIDOKey

# Find information on more than 1 AAGUID
"973446ca-e21c-9a9b-99f5-9b985a67af0f", "50a45b0c-80e7-f944-bf29-f552bfa2e048" | Find-FIDOKey

# Import multiple AAGUID from a file (.xslx, .csv, and .txt)
Find-FIDOKey -AAGUIDFile "aaguid.xlsx"

# Find your databse version and compare to newest version
Show-FIDODbVersion

# View Master Database Log
Get-FIDODbLog
```

Brands:
This parameter is validated so if you start typing in a brand and press tab it will fill the rest of the brand name in if it is available.

Type:
The four types of keys are USB, NFC, BIO, and BLE which are also validated in so you can tab complete.

AllProperties:
Shows all properties from the FIDO Alliance in JSON format

DetailedProperties:
Allows you to pull any property from the FIDO Alliance, but some you may have to play with depending on how nested they are.

If you are curious on the FIDO Alliance data, I've now added that into the metadata and it will be compared once a month when the FIDO Alliance publishes the newest version. It is accessible in the PowerShell version using the -AllProperties parameter, or in the web version by clicking on the actual key, then clicking on "Show Raw Data."

Also check out the web version: [https://devclate.github.io/EntraFIDOFinder/Explorer/](https://devclate.github.io/EntraFIDOFinder/Explorer/)
