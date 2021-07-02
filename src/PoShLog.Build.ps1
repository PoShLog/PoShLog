param (
	[Parameter(Mandatory = $false)]
	[Version]$ModuleVersion,

	[Parameter(Mandatory = $false)]
	[AllowEmptyString()]
	[AllowNull()]
	[string]$PreRelease = $null,

	[Parameter(Mandatory = $false)]
	[AllowEmptyString()]
	[AllowNull()]
	[string]$ReleaseNotes,

	[Parameter(Mandatory = $false)]
	[ValidateSet('Dev', 'Prod')]
	[string]$Configuration = 'Dev'
)

$moduleName = 'PoShLog'

#region use the most strict mode
Set-StrictMode -Version Latest
#endregion

#region Task clean up Output folder
task Clean {
	# Clean output folder
	if ((Test-Path '.\output')) {
		Remove-Item -Path '.\output\*' -Recurse -Force
	}
	Remove-Item -Path '.\lib\*' -Recurse -Force
}
#endregion

#region Task to run all Pester tests in folder .\tests
task Test {
	$testsDir = '.\..\tests'
	if (Test-Path $testsDir) {
		$Result = Invoke-Pester $testsDir -PassThru
		if ($Result.FailedCount -gt 0) {
			throw 'Pester tests failed'
		}
	}
}
#endregion

#region Task to build dotnet files into libraries
task BuildDependencies {
	if($env:PS_DEBUG){
		Import-Module "$PSScriptRoot\..\..\PoShLog.Tools\src\output\PoShLog.Tools"
	}
	else{
		Import-Module PoShLog.Tools
	}
	Build-Dependencies '.\dotnet\PoShLog.Core.csproj' -ModuleDirectory $PSScriptRoot
}
#endregion

#region Task to update the Module Manifest file
task UpdateManifest {

	# Get all function names
	$functions = @()
	Get-ChildItem -Path "$PSScriptRoot\functions" -Recurse -File -Filter '*.ps1' | ForEach-Object {
		# Export all functions except internal
		if ($_.FullName -notlike '*\internal\*') {
			$functions += $_.BaseName
		}
	}

	# Export all C# cmdlet names from binary module
	$cmdlets = @()
	Get-ChildItem -Path "$PSScriptRoot\dotnet\Cmdlets" -Recurse -File -Filter '*.cs' | ForEach-Object {
		$split = [System.Text.RegularExpressions.Regex]::Split($_.BaseName, "([A-Z]{1}[a-z]+)") | Where-Object { $_  -ne '' } | Select-Object -First 1
		$cmdlets += ($_.BaseName -replace $split, "$split-")
	}

	# Update RequiredAssemblies with all embedded dlls from \lib folder
	# $libs = @()
	# Get-ChildItem -Path "$PSScriptRoot\lib" -Recurse -File -Filter '*.dll' | ForEach-Object {
	# 	$libs += $_.FullName
	# }

	# If user didn't pass new module version, we need to load current version
	$manifestFile = "$PSScriptRoot\$moduleName.psd1"
	$manifest = $null
	if ($null -eq $ModuleVersion) {
		$manifest = Test-ModuleManifest -Path $manifestFile
		$ModuleVersion = $manifest.Version
	}
	Write-Output ('New Module version: {0}-{1}' -f $ModuleVersion, $PreRelease)

	# Create link to release notes markdown file
	if ([string]::IsNullOrEmpty($ReleaseNotes)) {
		if ($null -eq $manifest) {
			$manifest = Test-ModuleManifest -Path $manifestFile
		}

		$ReleaseNotes = "$($manifest.PrivateData.PSData.ProjectUri)/blob/master/releaseNotes/v$($ModuleVersion).md"
	}

	# Update module manifest with all information
	Update-ModuleManifest $manifestFile -ModuleVersion $ModuleVersion -Prerelease $Prerelease -FunctionsToExport $functions -CmdletsToExport $cmdlets -ReleaseNotes $ReleaseNotes
}
#endregion

#region Task to Copy PowerShell Module files to output folder for release as Module
task CopyModuleFiles {

	# Copy Module Files to Output Folder
	$moduleDirectory = ".\output\$moduleName"
	if (-not (Test-Path $moduleDirectory)) {

		New-Item -Path $moduleDirectory -ItemType Directory | Out-Null
	}

	Copy-Item -Path '.\functions\' -Filter *.* -Recurse -Destination $moduleDirectory -Force
	Copy-Item -Path '.\lib\' -Filter *.* -Recurse -Destination $moduleDirectory -Force

	#Copy Module Manifest files
	Copy-Item -Path @(
		'.\..\README.md'
		".\$moduleName.psd1"
		".\$moduleName.psm1"
	) -Destination $moduleDirectory -Force        
}
#endregion

#region Task to Publish Module to PowerShell Gallery
task PublishModule -If ($Configuration -eq 'Prod') {
	# Build a splat containing the required details and make sure to Stop for errors which will trigger the catch
	$params = @{
		Path        = "$PSScriptRoot\output\$moduleName"
		NuGetApiKey = $env:psgalleryapikey
		ErrorAction = 'Stop'
	}
	Publish-Module @params

	Write-Host "$moduleName successfully published to the PowerShell Gallery"
}
#endregion

#region Default Task. Runs Clean, Test, CopyModuleFiles Tasks
task . Clean, BuildDependencies, UpdateManifest, CopyModuleFiles, PublishModule
#endregion