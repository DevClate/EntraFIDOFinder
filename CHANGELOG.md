# Changelog

Here you will find all changes per version

## v0.0.13

**Enhancements**

* Filter by FIDO version from FIDO Alliance (PowerShell and Web Version)
  * Using ValidateSet for versions ("FIDO U2F", "FIDO 2.0", "FIDO 2.1", "FIDO 2.1 PRE")
* Added -AllProperties
  * Default to terminal shows basic fields, but added -AllProperties that I’ll add more of the useful fields first
* Show-FIDODbVersion now shows you your current version and if it needs to be updated

## v0.0.11

**Changes**

* Database Updated (see Merge Logs)

## v0.0.10

**Changes**

* Removed Requirement for PSParseHTML as it is not needed as of yet

## v0.0.9

**Enhancements**

* Fixed Log Output
* Created Get-FIDODbLog
  * You can view the master database log from terminal
* FidoKeys.json automatically copies to web version on update
* Database Updated - See Database Log File

## v0.0.8

**Enhancements**

- See what version of database you have and see what the newest version is (No longer need to use -NewestVersion parameter, it does it automatically)
- Show last time Database was checked for newest updates
- Created a merge log that when there is a change it will show the changes that occurred

## v0.0.7

**Enhancements**

- Ability to see your current database version and what is the newest version out

## v0.0.6

**Enhancements**

- Added database last updated field

**Fixed**

- JSON path for Keys now working in ./Assets/FidoKeys.json
