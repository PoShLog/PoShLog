[string] $Global:packagesPath = "$PSScriptRoot\packages"
[string] $Global:packagesConfigPath = "$PSScriptRoot\packages.config"

function Restore-AllExtensions{
	# Restore all nuget packages from packages.config
	& "$PSScriptRoot\tools\Nuget-Restore.ps1"
}

function New-Logger{
	$assemblies = Get-ChildItem "$($Global:packagesPath)\*\lib\*" | Where-Object { $_.Name -match 'net\d+' } | ForEach-Object { "$($_.FullName)\*.dll" } 
	Add-Type $assemblies

	New-Object Serilog.LoggerConfiguration
}

function Install-PoShLogExtension{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$Id,
		[Parameter(Mandatory=$true)]
		[string]$Version,
		[Parameter(Mandatory=$false)]
		[string]$TargetFramework = 'net461',
		[Parameter(Mandatory=$false)]
		[switch]$Restore
	)

	[xml]$xml = Get-Content $Global:packagesConfigPath
	$packages = $xml.SelectSingleNode("//packages")
	$package = $xml.SelectSingleNode("//package[@id='$Id']")

	if($Version -notmatch '(?<major>\d+|\*)(\.(?<minor>\d+|\*))?(\.(?<bugfix>\d+|\*))?'){
		Write-Error 'Wrong version format!'
		return
	}
	else{
		$targetVersionMajor = $Matches.Major
		$targetVersionMinor = $Matches.Minor
		$targetVersionBugfix = $Matches.Bugfix
	}	

	if($null -ne $package){
		$currentVersion = $package.Attributes | Where-Object { $_.Name -eq 'version' } | Select-Object -Property Value
		$currentVersion -match '(?<major>\d+|\*)(\.(?<minor>\d+|\*))?(\.(?<bugfix>\d+|\*))?' | Out-Null

		if($Matches.Major -lt $targetVersionMajor -or 
			($Matches.Major -eq $targetVersionMajor -and $Matches.Minor -lt $targetVersionMinor) -or
			($Matches.Major -eq $targetVersionMajor -and $Matches.Minor -eq $targetVersionMinor -and $Matches.Bugfix -lt $targetVersionBugfix)
		){
			$package.Attributes | Where-Object { $_.Name -eq 'version' } | ForEach-Object { $_.Value = $Version } 
			$changed = $true

			# Remove old package directory
			Remove-Item "$Global:packagesPath\$Id.$($currentVersion.Value)" -Recurse -Force
		}
		else{
			Write-Warning "Package $Id is already installed with same or higher version."
			return
		}
	}
	else{
		$package = $xml.CreateElement("package")

		$idAttr = $xml.CreateAttribute("id")
		$idAttr.Value = $Id
		$package.SetAttributeNode($idAttr);
	
		$versionAttr = $xml.CreateAttribute("version")
		$versionAttr.Value = $Version
		$package.SetAttributeNode($versionAttr);
	
		$targetFrameworkAttr = $xml.CreateAttribute("targetFramework")
		$targetFrameworkAttr.Value = $TargetFramework
		$package.SetAttributeNode($targetFrameworkAttr);
	
		$packages.AppendChild($package)
		$changed = $true
	}
	
	if($changed){
		$xml.Save($Global:packagesConfigPath)

		if($Restore){
			Restore-AllExtensions
		}
	}
}

function Add-SinkFile{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory=$true)]
		[string]$Path,
		[Parameter(Mandatory=$false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,
		[Parameter(Mandatory=$false)]
		[string]$OutputTemplate = '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}',
		[Parameter(Mandatory=$false)]
		[System.IFormatProvider]$FormatProvider = $null,
		[Parameter(Mandatory=$false)]
		[Nullable[int64]]$FileSizeLimitBytes = 1073741824L,
		[Parameter(Mandatory=$false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null,
		[Parameter(Mandatory=$false)]
		[switch]$Buffered,
		[Parameter(Mandatory=$false)]
		[switch]$Shared,
		[Parameter(Mandatory=$false)]
		[Nullable[timespan]]$FlushToDiskInterval = $null,
		[Parameter(Mandatory=$false)]
		[Serilog.RollingInterval]$RollingInterval = [Serilog.RollingInterval]::Infinite,
		[Parameter(Mandatory=$false)]
		[switch]$RollOnFileSizeLimit,
		[Parameter(Mandatory=$false)]
		[Nullable[int]]$RetainedFileCountLimit = 31,
		[Parameter(Mandatory=$false)]
		[System.Text.Encoding]$Encoding = $null
	)

	process{
		[Serilog.Configuration.LoggerSinkConfiguration]$loggerSinkConfig = $LoggerConfig.WriteTo

		$LoggerConfig = [Serilog.FileLoggerConfigurationExtensions]::File($loggerSinkConfig, 
			$Path, 
			$RestrictedToMinimumLevel,
			$OutputTemplate,
			$FormatProvider,
			$FileSizeLimitBytes,
			$LevelSwitch,
			$Buffered,
			$Shared,
			$FlushToDiskInterval,
			$RollingInterval,
			$RollOnFileSizeLimit,
			$RetainedFileCountLimit,
			$Encoding
		)

		$LoggerConfig
	}
}

function Add-SinkConsole{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig,
		[Parameter(Mandatory=$false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,
		[Parameter(Mandatory=$false)]
		[string]$OutputTemplate = '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}',
		[Parameter(Mandatory=$false)]
		[System.IFormatProvider]$FormatProvider = $null,
		[Parameter(Mandatory=$false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null,
		[Parameter(Mandatory=$false)]
		[Nullable[Serilog.Events.LogEventLevel]]$StandardErrorFromLevel = $null,
		[Parameter(Mandatory=$false)]
		[Serilog.Sinks.SystemConsole.Themes.ConsoleTheme]$Theme
	)

	process{
		[Serilog.Configuration.LoggerSinkConfiguration]$loggerSinkConfig = $loggerConfig.WriteTo
	
		$loggerConfig = [Serilog.ConsoleLoggerConfigurationExtensions]::Console($loggerSinkConfig,
			$RestrictedToMinimumLevel,
			$OutputTemplate,
			$FormatProvider,
			$LevelSwitch,
			$StandardErrorFromLevel,
			$Theme
		)

		$loggerConfig
	}
}

function Add-EnrichWithMachineName{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	process{
		[Serilog.Configuration.LoggerEnrichmentConfiguration]$loggerEnrichConfig = $loggerConfig.Enrich
	
		$loggerConfig = [Serilog.EnvironmentLoggerConfigurationExtensions]::WithMachineName($loggerEnrichConfig)

		$loggerConfig
	}
}

function Start-Logger{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	[Serilog.Log]::Logger = $loggerConfig.CreateLogger()
}

function Write-VerboseLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Verbose($Text)
}

function Write-DebugLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Debug($Text)
}

function Write-InfoLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Information($Text)
}

function Write-WarningLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Warning($Text)
}


function Write-ErrorLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Error($Text)
}

function Close-Logger{
	[Serilog.Log]::CloseAndFlush()
}

Install-PoShLogExtension -Id 'Serilog' -Version '2.8.0'
Install-PoShLogExtension -Id 'Serilog.Enrichers.Process' -Version '2.0.1' -Restore

New-Logger | 
	Add-EnrichWithMachineName | 
	Add-SinkFile -Path "C:\Logs\test.txt" | 
	Add-SinkConsole -OutputTemplate "[{Timestamp:HH:mm:ss} {Level:u3}] {MachineName} {Message:lj}{NewLine}{Exception}" | 
	Start-Logger

Write-InfoLog "poshlog"
Write-WarningLog "test warning"
Write-ErrorLog "test error"

Close-Logger