# EntraFIDOFinder ![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/EntraFIDOFinder?label=Downloads&style=flat-square) [![Platform](https://img.shields.io/badge/platform-Windows%20/%20Linux%20/%20Mac-blue)](https://github.com/DevClate/EntraFIDOFinder) [![Maintenance](https://img.shields.io/maintenance/yes/2024)](https://github.com/DevClate/EntraFIDOFinder)


PowerShell Module to find compatible attestation FIDO2 keys for Entra.

**Database Last Updated:** 2024-10-29

If you have trouble with the json path, please update to v0.0.5+ and it will fix your issue.

This readme is still in progress, but wanted to give you quick basics for people unfamiliar with PowerShell.

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
# Find your databse version and compare to newest version
Show-FIDODbVersion
# View Master Database Log
Get-FIDODbLog
```

Also the brands parameter is validated so if you start typing in a brand and press tab it will fill the rest of the brand name in if it is available. I have all compatible brands in there as of Sept 30, 2024.

The four types of keys are USB, NFC, BIO, and BLE which are also validated in so you can tab complete.

Also check out the web version: [https://devclate.github.io/EntraFIDOFinder/Explorer/](https://devclate.github.io/EntraFIDOFinder/Explorer/)
