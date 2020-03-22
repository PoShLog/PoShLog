# Simple script for publishing PoShlog Module
param(
	[Parameter(Mandatory = $true)]
	[Version]$TargetVersion
)

$srcFolder = "$PSScriptRoot\src"
$libFolder = "$PSScriptRoot\src\lib"
$publishFolder = "$PSScriptRoot\publish\PoShLog\"
$excludedItems = Get-Content "$PSScriptRoot\.publishExclude"

& "$PSScriptRoot\Build.ps1"

# Update module version
Update-ModuleManifest "$srcFolder\PoShLog.psd1" -ModuleVersion $TargetVersion

# Create clean publish folder
if (Test-Path $publishFolder) {
	Remove-Item $publishFolder -Recurse -Force
}
New-Item -Path $publishFolder -ItemType Directory -Force | Out-Null

# Remove unecessary files
Get-ChildItem $libFolder | Where-Object { $_.Name -like '*PoShLogLibs*' } | Remove-Item -Force

# Filter module files and move them to publish folder
Get-ChildItem $srcfolder | Where-Object { $excludedItems -notcontains $_.Name } | Select-Object -ExpandProperty FullName | Copy-Item -Destination $publishFolder -Recurse -Force

# Add readme to published modules
Copy-Item "$PSScriptRoot\README.md" -Destination $publishFolder

# Test module
Import-Module $publishFolder
Get-Module -Name PoShLog

Start-Logger -FilePath "$PSScriptRoot\published.log" -Console

Write-InfoLog 'SuccessFully published!'

Close-Logger

Publish-Module -NuGetApiKey '' -Path $publishFolder