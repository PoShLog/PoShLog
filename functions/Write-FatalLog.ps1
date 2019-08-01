function Write-FatalLog {
	param(
		[Parameter(Mandatory = $true, ParameterSetName = 'Text')]
		[string]$Text,
		[Parameter(Mandatory = $true, ParameterSetName = 'Excetion')]
		[Exception]$Exception,
		[Parameter(Mandatory = $true, ParameterSetName = 'Excetion')]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[switch]$PassThru
	)

	switch ($PsCmdlet.ParameterSetName){
		'Text'{
			[Serilog.Log]::Logger.Fatal($Text)
		}
		'Excetion'{
			[Serilog.Log]::Logger.Fatal($Exception, $MessageTemplate)
		}
	}

	if($PassThru){
		$Text
	}
}