function Set-DefaultMessageFormatter {
	
	param(
		[Parameter(Mandatory = $true)]
		[string]$Template
	)
	
	$global:TextFormatter = [Serilog.Formatting.Display.MessageTemplateTextFormatter]::new($Template)
}