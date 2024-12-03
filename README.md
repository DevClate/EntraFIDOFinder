# EntraFIDOFinder ![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/EntraFIDOFinder?label=Downloads&style=flat-square) [![Platform](https://img.shields.io/badge/platform-Windows%20/%20Linux%20/%20Mac-blue)](https://github.com/DevClate/EntraFIDOFinder) [![Maintenance](https://img.shields.io/maintenance/yes/2024)](https://github.com/DevClate/EntraFIDOFinder)


PowerShell Module to find compatible attestation FIDO2 keys for Entra.

**Database Last Updated:** 2024-12-02

If you have trouble with the json path, please update to v0.0.5+ and it will fix your issue.

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
# Find keys that are FIDO 2.1 with all properties
Find-FIDOKey -FIDOVersion "FIDO 2.1" -AllProperties
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
Right now I've only added last time FIDO Alliance has updated their information for that key, but I will be adding more in the very near future. Trying to find the best way to do it so its easy to read.

Also check out the web version: [https://devclate.github.io/EntraFIDOFinder/Explorer/](https://devclate.github.io/EntraFIDOFinder/Explorer/)
