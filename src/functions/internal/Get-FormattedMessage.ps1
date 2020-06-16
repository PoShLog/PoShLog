function Get-FormattedMessage{
	param(
		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEventLevel]$LogLevel,
		[parameter(Mandatory = $true)]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[object[]]$PropertyValues,
		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[System.Exception]$Exception
	)

	$parsedTemplate = $null
	$boundProperties = $null
	if ($global:PowerShellSink.DefaultLoggerImpl.BindMessageTemplate($MessageTemplate, $PropertyValues, [ref]$parsedTemplate, [ref]$boundProperties))
	{
		$logEvent = [Serilog.Events.LogEvent]::new([System.DateTimeOffset]::Now, $LogLevel, $Exception, $parsedTemplate, $boundProperties)
		$strWriter = [System.IO.StringWriter]::new()
		$global:PowerShellSink.TextFormatter.Format($logEvent, $strWriter)
		$message = $strWriter.ToString()
		$strWriter.Dispose()
		$message
	}
}