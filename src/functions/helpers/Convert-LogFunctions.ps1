function Convert-LogFunctions {
	<#
	.SYNOPSIS
		Converts default cmdlets in given script file into logger methods
	.DESCRIPTION
		Converts default cmdlets in given script file into logger methods. For example Write-Information into Write-InfoLog, Write-Error into Write-ErrorLog and so on.
	.PARAMETER FilePath
		Path to a script file in wich functions will be converted.
	.INPUTS
		string containing path to a script file
	.OUTPUTS
		None
	.EXAMPLE
		PS>  Convert-LogFunctions -FilePath C:\myscript.ps1
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$FilePath
	)

	Write-Debug "Converting $FilePath"

	$script = Get-Content $FilePath
	$script | Foreach-Object {
		$_ -replace 'Write-Verbose -Message', 'Write-VerboseLog -MessageTemplate' `
		   -replace 'Write-Verbose ', 'Write-VerboseLog ' `
		   -replace 'Write-Debug -Message', 'Write-DebugLog -MessageTemplate' `
		   -replace 'Write-Debug ', 'Write-DebugLog ' `
		   -replace 'Write-Information -MessageData', 'Write-InfoLog -MessageTemplate' `
		   -replace 'Write-Information ', 'Write-InfoLog ' `
		   -replace 'Write-Host -Object', 'Write-InfoLog -MessageTemplate' `
		   -replace 'Write-Host ', 'Write-InfoLog ' `
		   -replace 'Write-Warning -Message', 'Write-WarningLog -MessageTemplate' `
		   -replace 'Write-Warning ', 'Write-WarningLog ' `
		   -replace 'Write-Error -Message', 'Write-ErrorLog -MessageTemplate' `
		   -replace 'Write-Error ', 'Write-ErrorLog ' `
		} | Set-Content $FilePath

	Write-Debug "$FilePath successfully converted"
}