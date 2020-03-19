# Simple script for publishing PoShlog Module
param(
	[Parameter(Mandatory = $true)]
	[Version]$TargetVersion
)

$srcFolder = "$PSScriptRoot\src"
$libFolder = "$PSScriptRoot\src\lib"
$excludedItems = Get-Content "$PSScriptRoot\.publishExclude"

& "$PSScriptRoot\Build.ps1"

# Update module version
Update-ModuleManifest "$srcFolder\PoShLog.psd1" -ModuleVersion $TargetVersion

# Remove unecessary files
Get-ChildItem $libFolder | Where-Object { $_.Name -like '*PoShLogLibs*' } | Remove-Item -Force

$publishFolder = "$PSScriptRoot\publish\PoShLog\"
if (Test-Path $publishFolder) {
	Remove-Item $publishFolder -Recurse -Force
}

New-Item -Path $publishFolder -ItemType Directory -Force | Out-Null

# Filter module files and move them to publish folder
Get-ChildItem $srcfolder | Where-Object { $excludedItems -notcontains $_.Name } | Select-Object -ExpandProperty FullName | Copy-Item -Destination $publishFolder -Recurse

# Test module
Import-Module $publishFolder
Get-Module -Name PoShLog

Start-Logger -FilePath "$PSScriptRoot\published.log"

Write-InfoLog 'SuccessFully published!'