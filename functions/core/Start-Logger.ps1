function Start-Logger{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	[Serilog.Log]::Logger = $loggerConfig.CreateLogger()
}