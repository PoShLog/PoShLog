param (
	[Parameter(Mandatory = $false)]
	[Version]$ModuleVersion,

	[Parameter(Mandatory = $false)]
	[AllowEmptyString()]
	[AllowNull()]
	[string]$PreRelease,

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

task BuildDependencies {
	Import-Module PoShLog.Tools
	Build-Dependencies '.\dotnet\PoShLog.Core.csproj' -ModuleDirectory $PSScriptRoot
}

#region Task to update the Module Manifest file with info from the Changelog in Readme.
task UpdateManifest {

	$manifestFile = "$PSScriptRoot\$moduleName.psd1"
	$manifest = $null
	if ($null -eq $ModuleVersion) {
		$manifest = Test-ModuleManifest -Path $manifestFile
		$ModuleVersion = $manifest.Version
	}
	Write-Output ('New Module version: {0}-{1}' -f $ModuleVersion, $PreRelease)

	if ([string]::IsNullOrEmpty($ReleaseNotes)) {
		if ($null -eq $manifest) {
			$manifest = Test-ModuleManifest -Path $manifestFile
		}

		$ReleaseNotes = "$($manifest.PrivateData.PSData.ProjectUri)/blob/master/releaseNotes/v$($ModuleVersion).md"
	}

	# Comment out Prerelease property if its empty
	if ([string]::IsNullOrEmpty($Prerelease)) {
		(Get-Content $manifestFile) -replace '[^#]\sPrerelease\s=', '# Prerelease =' | Set-Content $manifestFile
	}

	# Update module version. PoShLog is now a compiled binary module, so cmdlets are exported
	# directly from the built assembly (CmdletsToExport in the manifest) instead of being
	# discovered from loose .ps1 function files.
	Update-ModuleManifest $manifestFile -ModuleVersion $ModuleVersion -Prerelease $Prerelease -ReleaseNotes $ReleaseNotes
}
#endregion

#region Task to Copy PowerShell Module files to output folder for release as Module
task CopyModuleFiles {

	# Copy Module Files to Output Folder
	$moduleDirectory = ".\output\$moduleName"
	if (-not (Test-Path $moduleDirectory)) {

		New-Item -Path $moduleDirectory -ItemType Directory | Out-Null
	}

	Copy-Item -Path '.\lib\' -Filter *.* -Recurse -Destination $moduleDirectory -Force

	#Copy Module Manifest files
	Copy-Item -Path @(
		'.\..\README.md'
		".\$moduleName.psd1"
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

	Write-Output "$moduleName successfully published to the PowerShell Gallery"
}
#endregion

#region Task clean up Output folder
task Clean {
	# Clean output folder
	if ((Test-Path '.\output')) {
		Remove-Item -Path '.\output\*' -Recurse -Force
	}
}
#endregion

#region Default Task. Runs Clean, Test, CopyModuleFiles Tasks
task . Clean, BuildDependencies, UpdateManifest, CopyModuleFiles, PublishModule
#endregion