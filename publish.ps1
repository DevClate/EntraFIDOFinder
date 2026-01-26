param(
    [Parameter(Mandatory)]
    [string]$NuGetApiKey,

    [string]$Path = (Join-Path $PSScriptRoot '.'),

    [string[]]$Exclude = @(
        '.github',
        'Explorer',
        'Scripts',
        'DESIGN_OPTION_*',
        'detailed_log.txt',
        'merge_log.txt',
        'merge_log.md',
        'FAmerge_log.txt',
        'publish.ps1',
        'start-server.sh',
        'FIDO_SYNC_*.md',
        'FIDO_KEY_CHANGES_*.md',
        '.fido_diff_state.json',
        'fido_diff_state.json',
        '*.psd1.bak'
    )
)

Write-Host "Publishing module from: $Path" -ForegroundColor Cyan
Write-Host "Excluding: $($Exclude -join ', ')" -ForegroundColor Cyan

Publish-Module -Path $Path -NuGetApiKey $NuGetApiKey -Exclude $Exclude -ErrorAction Stop

Write-Host "Publish complete." -ForegroundColor Green
