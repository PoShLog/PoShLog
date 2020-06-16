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