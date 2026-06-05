# FIDO2 Hardware Vendor Changes - March 2026

Generated: 2026-05-13 05:08:30
Source: [Microsoft Docs FIDO2 Vendor Page](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor)

---

## 2026-03-20 - Commit 86b16d5

**Total AAGUIDs:** 227

### Summary

- **Removed:** 3 authenticator(s)

### Removed Authenticators

- **Windows Hello Hardware Authenticator**
  - AAGUID: `08987058-cadc-4b81-b6e1-30de50dcbe96`
- **Windows Hello Software Authenticator**
  - AAGUID: `6028b017-b1d4-4c02-b4b3-afcdafc96bb2`
- **Windows Hello VBS Hardware Authenticator**
  - AAGUID: `9ddd1817-af5a-4672-a2b9-3e3dd95000a9`

## 2026-03-20 - Commit 1627afd

**Total AAGUIDs:** 230
**Note:** Apply vendor-reported capability corrections to FIDO2 table

Corrected USB, NFC, and BLE flags for 11 rows based on
vendor-reported corrections from MicrosoftDocs/entra-docs
commit 686d7ef.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>

### Summary

- **Modified:** 11 authenticator(s)

### Modified Authenticators

#### Feitian BioPass FIDO2 Authenticator

- **AAGUID:** `77010bd7-212a-4fc9-b236-d2ca5e9d4084`
- USB: 'No' → 'Yes'

#### Feitian ePass FIDO2-NFC Authenticator

- **AAGUID:** `ee041bce-25e5-4cdb-8f86-897fd6418464`
- USB: 'No' → 'Yes'
- NFC: 'No' → 'Yes'

#### Hyper FIDO Bio Security Key

- **AAGUID:** `d821a7d4-e97c-4cb6-bd82-4237731fd4be`
- USB: 'No' → 'Yes'

#### Hyper FIDO Pro

- **AAGUID:** `9f77e279-a6e2-4d58-b700-31e5943c6a98`
- USB: 'No' → 'Yes'

#### OneSpan DIGIPASS FX1a

- **AAGUID:** `30b5035e-d297-4ff1-010b-addc96ba6a98`
- NFC: 'No' → 'Yes'

#### OneSpan DIGIPASS FX7

- **AAGUID:** `30b5035e-d297-4ff7-b00b-addc96ba6a98`
- BLE: 'Yes' → 'No'

#### Security Key NFC by Yubico

- **AAGUID:** `e77e3c64-05e3-428b-8824-0cbeb04b829d`
- NFC: 'No' → 'Yes'

#### Security Key NFC by Yubico - Enterprise Edition

- **AAGUID:** `47ab2fb4-66ac-4184-9ae1-86be814012d5`
- NFC: 'No' → 'Yes'

#### Security Key NFC by Yubico - Enterprise Edition (Enterprise Profile)

- **AAGUID:** `9ff4cc65-6154-4fff-ba09-9e2af7882ad2`
- NFC: 'No' → 'Yes'

#### YubiKey 5 Series with NFC

- **AAGUID:** `a25342c0-3cdc-4414-8e46-f4807fca511c`
- NFC: 'No' → 'Yes'

#### YubiKey 5 Series with NFC (Enterprise Profile)

- **AAGUID:** `1ac71f64-468d-4fe0-bef1-0e5f2f551f18`
- NFC: 'No' → 'Yes'

## 2026-03-20 - Commit b7350d1

**Total AAGUIDs:** 230

### Summary

- **Added:** 15 authenticator(s)
- **Removed:** 12 authenticator(s)
- **Modified:** 14 authenticator(s)

### Added Authenticators

#### ATLKey Authenticator

- **AAGUID:** `019614a3-2703-7e35-a453-285fd06c5d24`
- **Capabilities:** USB

#### eToken FIDO NFC

- **AAGUID:** `b113a455-cfb6-4c17-8cba-cd952feb7d48`
- **Capabilities:** NFC

#### eToken Fusion BIO

- **AAGUID:** `d716019a-9f4e-4041-9750-17c78f8ae81a`
- **Capabilities:** Biometric, USB

#### HID Crescendo 4000

- **AAGUID:** `0b8b05a4-ebd4-4b0b-8f5f-33d7b6e606ab`
- **Capabilities:** NFC

#### HID Crescendo Key V3

- **AAGUID:** `87c13177-85d6-40ac-8c61-fe7ab3de9dfb`
- **Capabilities:** USB, NFC

#### IDEX CTAP2.1 Biometrics

- **AAGUID:** `49a15c1c-3f63-3f51-23a7-b9e00096edd1`
- **Capabilities:** Biometric, USB, NFC

#### Mettlesemi Vishwaas Eagle Authenticator using FIDO2

- **AAGUID:** `489ff376-b48d-6640-bb69-782a860ca795`
- **Capabilities:** USB

#### Mettlesemi Vishwaas Hawk Authenticator using FIDO2

- **AAGUID:** `bb66c294-de08-47e4-b7aa-d12c2cd3fb20`
- **Capabilities:** USB

#### Thales PAY GFCX13 authenticator

- **AAGUID:** `04a8fcf2-19c1-457b-911e-69219f17583f`
- **Capabilities:** NFC

#### VeriMark NFC+ USB-A Security Key

- **AAGUID:** `76692dc1-c56a-48d9-8e7d-31b5ced430ac`
- **Capabilities:** USB, NFC

#### VeriMark NFC+ USB-C Security Key

- **AAGUID:** `ee7fa1e0-9539-432f-bd43-9c2fc6d4f311`
- **Capabilities:** USB, NFC

#### Windows Hello Hardware Authenticator

- **AAGUID:** `08987058-cadc-4b81-b6e1-30de50dcbe96`
- **Capabilities:** Biometric

#### Windows Hello Software Authenticator

- **AAGUID:** `6028b017-b1d4-4c02-b4b3-afcdafc96bb2`
- **Capabilities:** Biometric

#### Windows Hello VBS Hardware Authenticator

- **AAGUID:** `9ddd1817-af5a-4672-a2b9-3e3dd95000a9`
- **Capabilities:** Biometric

#### WiSECURE AuthTron USB FIDO2 Authenticator

- **AAGUID:** `504d7149-4e4c-3841-4555-55445a677357`
- **Capabilities:** Biometric, USB

### Removed Authenticators

- **Excelsecu eSecu FIDO2 PRO+ Security Key**
  - AAGUID: `f573f209-b7fb-b261-671a-d7cf624cc812`
- **Feitian ePass FIDO2-NFC Plus Authenticator**
  - AAGUID: `260e3021-482d-442d-838c-7edfbe153b7e`
- **Hideez Key 3 FIDO2**
  - AAGUID: `3e078ffd-4c54-4586-8baa-a77da113aec5`
- **OCTATCO EzQuant FIDO2 AUTHENTICATOR**
  - AAGUID: `bc2fe499-0d8e-4ffe-96f3-94a82840cf8c`
- **OneKey FIDO2 Authenticator**
  - AAGUID: `69e7c36f-f2f6-9e0d-07a6-bcc243262e6b`
- **OneKey FIDO2 Bluetooth Authenticator**
  - AAGUID: `70e7c36f-f2f6-9e0d-07a6-bcc243262e6b`
- **Security Key NFC by Yubico - Enterprise Edition Preview**
  - AAGUID: `2772ce93-eb4b-4090-8b73-330f48477d73`
- **Security Key NFC by Yubico Preview**
  - AAGUID: `760eda36-00aa-4d29-855b-4012a182cdeb`
- **VivoKey Apex FIDO2**
  - AAGUID: `d7a423ad-3e19-4492-9200-78137dccc136`
- **WinMagic FIDO Eazy - Phone**
  - AAGUID: `f56f58b3-d711-4afc-ba7d-6ac05f88cb19`
- **WinMagic FIDO Eazy - Software**
  - AAGUID: `31c3f7ff-bf15-4327-83ec-9336abcbcd34`
- **YubiKey 5 Series with NFC Preview**
  - AAGUID: `34f5766d-1536-4a24-9033-0e294e510fb0`

### Modified Authenticators

#### Feitian BioPass FIDO2 Authenticator

- **AAGUID:** `77010bd7-212a-4fc9-b236-d2ca5e9d4084`
- USB: 'Yes' → 'No'

#### Feitian ePass FIDO2-NFC Authenticator

- **AAGUID:** `ee041bce-25e5-4cdb-8f86-897fd6418464`
- USB: 'Yes' → 'No'
- NFC: 'Yes' → 'No'

#### GoTrust Idem Key FIDO2 Authenticator

- **AAGUID:** `3b1adb99-0dfe-46fd-90b8-7f7614a4de2a`
- USB: 'No' → 'Yes'
- NFC: 'No' → 'Yes'

#### Hyper FIDO Bio Security Key

- **AAGUID:** `d821a7d4-e97c-4cb6-bd82-4237731fd4be`
- USB: 'Yes' → 'No'

#### Hyper FIDO Pro

- **AAGUID:** `9f77e279-a6e2-4d58-b700-31e5943c6a98`
- USB: 'Yes' → 'No'

#### IDmelon Authenticator

- **AAGUID:** `820d89ed-d65a-409e-85cb-f73f0578f82a`
- Description: 'IDmelon iOS Authenticator' → 'IDmelon Authenticator'

#### IDmelon Key

- **AAGUID:** `39a5647e-1853-446c-a1f6-a79bae9f5bc7`
- Description: 'IDmelon Android Authenticator' → 'IDmelon Key'

#### OneSpan DIGIPASS FX1a

- **AAGUID:** `30b5035e-d297-4ff1-010b-addc96ba6a98`
- NFC: 'Yes' → 'No'

#### OneSpan DIGIPASS FX7

- **AAGUID:** `30b5035e-d297-4ff7-b00b-addc96ba6a98`
- BLE: 'No' → 'Yes'

#### Security Key NFC by Yubico

- **AAGUID:** `e77e3c64-05e3-428b-8824-0cbeb04b829d`
- NFC: 'Yes' → 'No'

#### Security Key NFC by Yubico - Enterprise Edition

- **AAGUID:** `47ab2fb4-66ac-4184-9ae1-86be814012d5`
- NFC: 'Yes' → 'No'

#### Security Key NFC by Yubico - Enterprise Edition (Enterprise Profile)

- **AAGUID:** `9ff4cc65-6154-4fff-ba09-9e2af7882ad2`
- NFC: 'Yes' → 'No'

#### YubiKey 5 Series with NFC

- **AAGUID:** `a25342c0-3cdc-4414-8e46-f4807fca511c`
- NFC: 'Yes' → 'No'

#### YubiKey 5 Series with NFC (Enterprise Profile)

- **AAGUID:** `1ac71f64-468d-4fe0-bef1-0e5f2f551f18`
- NFC: 'Yes' → 'No'

## 2026-03-17 - Commit d7b06ee

**Total AAGUIDs:** 227
**Note:** Merge branch 'main' into synced-passkey-ga

### Summary

- **Added:** 3 authenticator(s)
- **Removed:** 49 authenticator(s)
- **Modified:** 3 authenticator(s)

### Added Authenticators

#### Clife Key 2

- **AAGUID:** `fc5ca237-69a0-4f3c-afe4-1ebc66def6df`
- **Capabilities:** USB

#### Clife Key 2 NFC

- **AAGUID:** `23315ad0-6aca-4ba1-952e-f044f1e36976`
- **Capabilities:** USB, NFC

#### Taglio CTAP2.1 BIO

- **AAGUID:** `0f00cc22-4640-41e7-9585-384ec73ffe9b`
- **Capabilities:** Biometric, USB, NFC

### Removed Authenticators

- **Android Authenticator**
  - AAGUID: `b93fd961-f2e6-462f-b122-82002247de78`
- **ATLKey Authenticator**
  - AAGUID: `019614a3-2703-7e35-a453-285fd06c5d24`
- **Dapple Authenticator from Dapple Security Inc.**
  - AAGUID: `6dae43be-af9c-417b-8b9f-1b611168ec60`
- **Deepnet SafeKey/Classic (FP)**
  - AAGUID: `e41b42a3-60ac-4afb-8757-a98f2d7f6c9f`
- **Deepnet SafeKey/Classic (USB)**
  - AAGUID: `b9f6b7b6-f929-4189-bca9-dd951240c132`
- **ellipticSecure MIRkey USB Authenticator**
  - AAGUID: `eb3b131e-59dc-536a-d176-cb7306da10f5`
- **Ensurity AUTH BioPro Desktop**
  - AAGUID: `9eb85bb6-9625-4a72-815d-0487830ccab2`
- **Ensurity AUTH TouchPro**
  - AAGUID: `50cbf15a-238c-4457-8f16-812c43bf3c49`
- **ESS Smart Card Inc. Authenticator**
  - AAGUID: `5343502d-5343-5343-6172-644649444f32`
- **eToken Fusion BIO**
  - AAGUID: `d716019a-9f4e-4041-9750-17c78f8ae81a`
- **eToken Fusion NFC PIV Enterprise**
  - AAGUID: `c3f47802-de73-4dfc-ba22-671fe3304f90`
- **eWBM eFA500 FIDO2 Authenticator**
  - AAGUID: `361a3082-0278-4583-a16f-72a527f973e4`
- **Feitian FIDO Smart Card**
  - AAGUID: `2c0df832-92de-4be1-8412-88a8f074df4a`
- **FIDO Alliance TruU Sample FIDO2 Authenticator**
  - AAGUID: `ca87cb70-4c1b-4579-a8e8-4efdd7c007e0`
- **GoldKey Security Token**
  - AAGUID: `0db01cd6-5618-455b-bb46-1ec203d3213e`
- **Ideem ZSM FIDO2 Authenticator**
  - AAGUID: `5e264d9d-28ef-4d34-95b4-5941e7a4faa8`
- **IDEMIA SOLVO Fly 80 R1 FIDO Card Draft**
  - AAGUID: `3fd410dc-8ab7-4b86-a1cb-c7174620b2dc`
- **IDEX CTAP2.1 Biometric, No pin**
  - AAGUID: `49a15c1c-3f63-3f51-23a7-b9e00096edd1`
- **KeyVault Secp256R1 FIDO2 CTAP2 Authenticator**
  - AAGUID: `d61d3b87-3e7c-4aea-9c50-441c371903ad`
- **Ledger Flex FIDO2 Authenticator**
  - AAGUID: `1d8cac46-47a1-3386-af50-e88ae46fe802`
- **Ledger Nano S FIDO2 Authenticator**
  - AAGUID: `341e4da9-3c2e-8103-5a9f-aad887135200`
- **Ledger Nano S Plus FIDO2 Authenticator**
  - AAGUID: `58b44d0b-0a7c-f33a-fd48-f7153c871352`
- **Ledger Nano X FIDO2 Authenticator**
  - AAGUID: `fcb1bcb4-f370-078c-6993-bc24d0ae3fbe`
- **Ledger Stax FIDO2 Authenticator**
  - AAGUID: `6e24d385-004a-16a0-7bfe-efd963845b34`
- **Mettlesemi Vishwaas Eagle Authenticator using FIDO2**
  - AAGUID: `489ff376-b48d-6640-bb69-782a860ca795`
- **Mettlesemi Vishwaas Hawk Authenticator using FIDO2**
  - AAGUID: `bb66c294-de08-47e4-b7aa-d12c2cd3fb20`
- **Pone Biometrics OFFPAD Authenticator**
  - AAGUID: `09591fc6-9811-48f7-8f57-b9f23df6413f`
- **Samsung Pass**
  - AAGUID: `53414d53-554e-4700-0000-000000000000`
- **SECORA ID V2 FIDO2.1 L1**
  - AAGUID: `4e2ddbc2-2687-4709-8551-cb66c9776bfe`
- **TEST (DUMMY RECORD)**
  - AAGUID: `ab32f0c6-2239-afbb-c470-d2ef4e254db6`
- **ToothPic Passkey Provider**
  - AAGUID: `cc45f64e-52a2-451b-831a-4edd8022a202`
- **TruU FIDO2 Authenticator**
  - AAGUID: `bb878d7b-cf54-4784-b390-357030497043`
- **TruU Windows Authenticator**
  - AAGUID: `95e4d58c-056e-4a65-866d-f5a69659e880`
- **TruU Windows Authenticator**
  - AAGUID: `ba86dc56-635f-4141-aef6-00227b1b9af6`
- **USB/NFC Passcode Authenticator**
  - AAGUID: `cfcb13a2-244f-4b36-9077-82b79d6a7de7`
- **Veridium Android SDK**
  - AAGUID: `5ea308b2-7ac7-48b9-ac09-7e2da9015f8c`
- **Veridium iOS SDK**
  - AAGUID: `6e8d1eae-8d40-4c25-bcf8-4633959afc71`
- **VeriMark NFC+ USB-A Security Key**
  - AAGUID: `76692dc1-c56a-48d9-8e7d-31b5ced430ac`
- **VeriMark NFC+ USB-C Security Key**
  - AAGUID: `ee7fa1e0-9539-432f-bd43-9c2fc6d4f311`
- **WinMagic FIDO Eazy - TPM**
  - AAGUID: `970c8d9c-19d2-46af-aa32-3f448db49e35`
- **WiSECURE AuthTron USB FIDO2 Authenticator**
  - AAGUID: `504d7149-4e4c-3841-4555-55445a677357`
- **WiSECURE Blentity FIDO2 Authenticator**
  - AAGUID: `5753362b-4e6b-6345-7b2f-255438404c75`
- **YubiKey 5 FIPS Series (RC Preview)**
  - AAGUID: `d2fbd093-ee62-488d-9dad-1e36389f8826`
- **YubiKey 5 FIPS Series with Lightning (RC Preview)**
  - AAGUID: `9e66c661-e428-452a-a8fb-51f7ed088acf`
- **YubiKey 5 FIPS Series with Lightning Preview**
  - AAGUID: `5b0e46ba-db02-44ac-b979-ca9b84f5e335`
- **YubiKey 5 FIPS Series with NFC (RC Preview)**
  - AAGUID: `ce6bf97f-9f69-4ba7-9032-97adc6ca5cf1`
- **YubiKey 5 FIPS Series with NFC Preview**
  - AAGUID: `62e54e98-c209-4df3-b692-de71bb6a8528`
- **YubiKey 5 Series with Lightning Preview**
  - AAGUID: `3124e301-f14e-4e38-876d-fbeeb090e7bf`
- **ZTPass SmartAuth**
  - AAGUID: `99bf4610-ec26-4252-b31f-7380ccd59db5`

### Modified Authenticators

#### Feitian ePass FIDO2 Authenticator

- **AAGUID:** `833b721a-ff5f-4d00-bb2e-bdda3ec01e29`
- USB: 'Yes' → 'No'

#### GoTrust Idem Key (Consumer profile)

- **AAGUID:** `c611b55c-77b2-4527-8082-590e931b2f08`
- Description: 'Idem Key (Consumer profile)' → 'GoTrust Idem Key (Consumer profile)'

#### OCTATCO EzQuant FIDO2 AUTHENTICATOR

- **AAGUID:** `bc2fe499-0d8e-4ffe-96f3-94a82840cf8c`
- USB: 'Yes' → 'No'

## 2026-03-08 - Commit f229ee5

**Total AAGUIDs:** 273
**Note:** Copyedit FIDO2 hardware vendor and synced passkeys docs

Fix note formatting, WebAuthn casing, HMAC expansion, link text,
idiom corrections, and trailing whitespace per Microsoft style.
Update prerequisites in synced passkeys doc.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Commits Analyzed | 5 |
| Date Range | 2026-03-08 to 2026-03-20 |
| Current Total AAGUIDs | 227 |
| Net Change | -46 |

---

*This changelog was generated from the [Microsoft Docs FIDO2 Hardware Vendor page](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor).*
