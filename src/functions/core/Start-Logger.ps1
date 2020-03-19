function Start-Logger {
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Full')]
		[Serilog.LoggerConfiguration]$loggerConfig,
		[Parameter(Mandatory = $true, ParameterSetName = 'Short')]
		[string]$FilePath,
		[Parameter(Mandatory = $false, ParameterSetName = 'Short')]
		[Serilog.Events.LogEventLevel]$MinimumLevel = [Serilog.Events.LogEventLevel]::Debug,
		[Parameter(Mandatory = $false, ParameterSetName = 'Short')]
		[Serilog.RollingInterval]$FileRollingInterval = [Serilog.RollingInterval]::Infinite
	)

	switch ($PsCmdlet.ParameterSetName) {
		'Full' {
			[Serilog.Log]::Logger = $loggerConfig.CreateLogger()
		}
		'Short' {
			$loggerConfig = New-Logger | Set-MinimumLevel -MinimumLevel $MinimumLevel | Add-SinkFile -Path $FilePath -RollingInterval $FileRollingInterval | Add-SinkConsole
			[Serilog.Log]::Logger = $loggerConfig.CreateLogger()
		}
	}
}