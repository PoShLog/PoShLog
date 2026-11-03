#Requires -Version 7.4
# The code under test: a function that logs through PoShLog's public commands.

function Invoke-Backup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (!(Test-Path -LiteralPath $Source -PathType Container)) {
        Write-ErrorLog 'Backup source {Source} does not exist' -PropertyValues $Source
        throw "Backup source '$Source' does not exist."
    }
    New-Item -ItemType Directory -Force $Destination | Out-Null
    $files = @(Get-ChildItem -LiteralPath $Source -File)
    foreach ($file in $files) {
        Copy-Item -LiteralPath $file.FullName -Destination $Destination
        Write-DebugLog 'Copied {File}' -PropertyValues $file.Name
    }
    Write-InfoLog 'Copied {FileCount} files from {Source} to {Destination}' -PropertyValues $files.Count, $Source, $Destination
}
