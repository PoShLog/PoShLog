[bool] $Global:loggerNotInitWarned = $false	# Indicates wether warning about logger is not initialized was shown
$global:PowerShellSinks = @{}

# Load all package dlls
. "$PSScriptRoot\functions\internal\Add-PackageTypes.ps1"
Add-PackageTypes -LibsDirectory "$PSScriptRoot\lib"

# dot source all script files
Get-ChildItem -Path "$PSScriptRoot\functions" -Recurse -File -Filter '*.ps1' | ForEach-Object {
	. $_.FullName

	# Export all functions except internal
	if ($_.FullName -notlike '*\internal\*') {
		Export-ModuleMember $_.BaseName
	}
}

# Remove package directory from previous version
[string] $obsoletePackagesPath = "$env:APPDATA\PoShLog\packages"
if (Test-Path $obsoletePackagesPath ) {
	Remove-Item $obsoletePackagesPath -Recurse -Force -ErrorAction SilentlyContinue
}

$global:TextFormatter = [Serilog.Formatting.Display.MessageTemplateTextFormatter]::new('{Message:lj}')
[Serilog.Core.Logger]$global:DefaultLoggerImpl = [Serilog.LoggerConfiguration]::new().CreateLogger()