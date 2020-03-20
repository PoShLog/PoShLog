function Start-Logger {
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Full')]
		[Serilog.LoggerConfiguration]$loggerConfig,

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
				$loggerConfig = New-Logger | Set-MinimumLevel -MinimumLevel $MinimumLevel

				# If file path was not passed we setup default console sink
				if($Console -or -not $PSBoundParameters.ContainsKey('FilePath')){
					$loggerConfig = $loggerConfig | Add-SinkConsole
				}

				if($PSBoundParameters.ContainsKey('FilePath')){
					$loggerConfig = $loggerConfig | Add-SinkFile -Path $FilePath -RollingInterval $FileRollingInterval
				}
			}
		}
	
		[Serilog.Log]::Logger = $loggerConfig.CreateLogger()
	}
}
