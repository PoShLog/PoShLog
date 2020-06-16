class PowerShellSink {
	[Serilog.Formatting.ITextFormatter]$TextFormatter
	[ValidateNotNullOrEmpty()][string]$OutputTemplate
	[Serilog.Core.Logger]$DefaultLoggerImpl = [Serilog.LoggerConfiguration]::new().CreateLogger()

	PowerShellSink(
		[string]$outputTemplate
	) {
		$this.OutputTemplate = $outputTemplate
		$this.TextFormatter = [Serilog.Formatting.Display.MessageTemplateTextFormatter]::new($outputTemplate)
	}
}

function Add-SinkPowerShell {
	<#
	.SYNOPSIS
		Writes log events to powershell host
	.DESCRIPTION
		Writes log events to powershell host
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER OutputTemplate
		A message template describing the format used to write to the sink.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> Add-SinkPowerShell
	.EXAMPLE
		PS> Add-SinkPowerShell -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}"
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $false)]
		[string]$OutputTemplate = '{Message:lj}'
	)

	process {	
		$global:PowerShellSink = [PowerShellSink]::new($OutputTemplate)

		$LoggerConfig
	}
}