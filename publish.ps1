param(
    [Parameter(Mandatory)]
    [string]$NuGetApiKey,

    [string]$Path = (Join-Path $PSScriptRoot '.')
)

Write-Host "Publishing module from: $Path" -ForegroundColor Cyan
Write-Host "Using exclusions defined in EntraFIDOFinder.psd1" -ForegroundColor Cyan

Publish-Module -Path $Path -NuGetApiKey $NuGetApiKey -ErrorAction Stop

Write-Host "Publish complete!" -ForegroundColor Green

Write-Host "Publish complete." -ForegroundColor Green
