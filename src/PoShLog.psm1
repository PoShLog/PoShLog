# Indicates wether warning about logger is not initialized was shown
[bool] $Global:loggerNotInitWarned = $false

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

# Default text formatter for Get-FormattedMessage cmdlet
$global:TextFormatter = [Serilog.Formatting.Display.MessageTemplateTextFormatter]::new('{Message:lj}')