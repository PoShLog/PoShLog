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
		[PowerShellSink]$PowerShellSink,

		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[object[]]$PropertyValues,

		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[System.Exception]$Exception
	)

	
	if($null -ne $PowerShellSink){
		$textFormatter = $PowerShellSink.TextFormatter
	}
	else {
		$textFormatter = $global:TextFormatter
	}

	$parsedTemplate = $null
	$boundProperties = $null
	if ($Logger.BindMessageTemplate($MessageTemplate, $PropertyValues, [ref]$parsedTemplate, [ref]$boundProperties))
	{
		$logEvent = [Serilog.Events.LogEvent]::new([System.DateTimeOffset]::Now, $LogLevel, $Exception, $parsedTemplate, $boundProperties)
		$strWriter = [System.IO.StringWriter]::new()
		$textFormatter.Format($logEvent, $strWriter)
		$message = $strWriter.ToString()
		$strWriter.Dispose()
		$message
	}
}