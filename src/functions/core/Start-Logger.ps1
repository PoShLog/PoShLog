function Start-Logger {
	<#
	.SYNOPSIS
		Starts logging
	.DESCRIPTION
		Creates new instance of logger, that writes to configured sinks.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration that is already setup.
	.PARAMETER MinimumLevel
		Configures the minimum level at which events will be passed to sinks. All messages with levels beneath this level will be ignored.
	.PARAMETER Console
		Setups console sink. All messages will be writen to console host.
	.PARAMETER FilePath
		Setups File sink at given path. All messages will be written to given file path.
	.PARAMETER FileRollingInterval
		The interval at which logging will roll over to a new file.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		None
	.EXAMPLE
		PS> New-Logger | Add-SinkConsole | Start-Logger
	.EXAMPLE
		PS> Start-Logger
	.EXAMPLE
		PS> Start-Logger -MinimumLevel Verbose -Console -FilePath 'C:\Data\test.log' -FileRollingInterval Day
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Full')]
		[Serilog.LoggerConfiguration]$LoggerConfig,

		[Parameter(Mandatory = $false, ParameterSetName = 'Short')]
		[Serilog.Events.LogEventLevel]$MinimumLevel = [Serilog.Events.LogEventLevel]::Debug,

		[Parameter(Mandatory = $false, ParameterSetName = 'Short')]
		[switch]$Console,

		[Parameter(Mandatory = $false, ParameterSetName = 'Short')]
		[string]$FilePath,
		
		[Parameter(Mandatory = $false, ParameterSetName = 'Short')]
		[Serilog.RollingInterval]$FileRollingInterval = [Serilog.RollingInterval]::Infinite
	)

	process{
		switch ($PsCmdlet.ParameterSetName) {
			'Short' {
				$LoggerConfig = New-Logger | Set-MinimumLevel -MinimumLevel $MinimumLevel

				# If file path was not passed we setup default console sink
				if($Console -or -not $PSBoundParameters.ContainsKey('FilePath')){
					$LoggerConfig = $LoggerConfig | Add-SinkConsole
				}

				if($PSBoundParameters.ContainsKey('FilePath')){
					$LoggerConfig = $LoggerConfig | Add-SinkFile -Path $FilePath -RollingInterval $FileRollingInterval
				}
			}
		}
	
		[Serilog.Log]::Logger = $LoggerConfig.CreateLogger()
	}
}
