function Get-ElasticFormatter {
	<#
	.SYNOPSIS
		Returns new instance of Elastic.CommonSchema.Serilog.EcsTextFormatter.
	.DESCRIPTION
		Returns new instance of Elastic.CommonSchema.Serilog.EcsTextFormatter that can be used with File or Console sink.
	.INPUTS
		None
	.OUTPUTS
		Instance of Elastic.CommonSchema.Serilog.EcsTextFormatter
	.EXAMPLE
		PS> New-Logger | Add-SinkFile -Path 'C:\Data\Log\test.log' -Formatter (Get-ElasticFormatter) | Start-Logger
	#>

	[Elastic.CommonSchema.Serilog.EcsTextFormatter]::new()
}