function Get-FormattedMessage{
	param(
		[Parameter(Mandatory = $true)]
		[Serilog.ILogger]$Logger,

		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEventLevel]$LogLevel,

		[parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]$MessageTemplate,

		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[object[]]$PropertyValues,

		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[System.Exception]$Exception
	)

	$parsedTemplate = $null
	$boundProperties = $null
	if ($Logger.BindMessageTemplate($MessageTemplate, $PropertyValues, [ref]$parsedTemplate, [ref]$boundProperties))
	{
		$logEvent = [Serilog.Events.LogEvent]::new([System.DateTimeOffset]::Now, $LogLevel, $Exception, $parsedTemplate, $boundProperties)
		$strWriter = [System.IO.StringWriter]::new()
		$global:TextFormatter.Format($logEvent, $strWriter)
		$message = $strWriter.ToString()
		$strWriter.Dispose()
		$message
	}
}