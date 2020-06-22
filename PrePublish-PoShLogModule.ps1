# Simple script for publishing PoShlog Modules

param(
	[Parameter(Mandatory = $true)]
	[string]$ModuleDirectory,
	[Parameter(Mandatory = $true)]
	[Version]$TargetVersion,
	[Parameter(Mandatory = $false)]
	[string]$ReleaseNotes,
	[Parameter(Mandatory = $false)]
	[string]$ModuleName = (Get-Item $ModuleDirectory).BaseName,
	[Parameter(Mandatory = $false)]
	[string]$PublishFolder = "$PSScriptRoot\publish\$ModuleName\",
	[Parameter(Mandatory = $false)]
	[string]$ProjectPath = "$ModuleDirectory\Dependencies.csproj",
	[Parameter(Mandatory = $false)]
	[switch]$IsExtensionModule
)

$excludedItems = Get-Content "$PSScriptRoot\.publishExclude"

& "$PSScriptRoot\Build-Dependencies.ps1" -ProjectPath $ProjectPath -ModuleDirectory $ModuleDirectory -IsExtensionModule:$IsExtensionModule

# Remove unecessary files from lib folder
Remove-Item "$ModuleDirectory\lib\*.json" -Force
Remove-Item "$ModuleDirectory\lib\*.pdb" -Force
Remove-Item "$ModuleDirectory\lib\System.Management.Automation.dll" -Force

$functions = @()

Get-ChildItem -Path "$ModuleDirectory\functions" -Recurse -File -Filter '*.ps1' | ForEach-Object {
	# Export all functions except internal
	if ($_.FullName -notlike '*\internal\*') {
		$functions += $_.BaseName
	}
}

# Update module version
Update-ModuleManifest "$ModuleDirectory\$ModuleName.psd1" -ModuleVersion $TargetVersion -ReleaseNotes $ReleaseNotes -FunctionsToExport $functions

# Create clean publish folder
if (Test-Path $PublishFolder) {
	Remove-Item $PublishFolder -Recurse -Force
}
New-Item -Path $PublishFolder -ItemType Directory -Force | Out-Null

# Filter module files and move them to publish folder
Get-ChildItem $ModuleDirectory | Where-Object { $excludedItems -notcontains $_.Name } | Select-Object -ExpandProperty FullName | Copy-Item -Destination $PublishFolder -Recurse -Force