function Write-SinkPowerShell {
	param(
		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEvent]$LogEvent,
		[Parameter(Mandatory = $true)]
		[string]$RenderedMessage
	)

	switch ($LogEvent.Level) {
		Verbose { 
			Write-Verbose -Message $RenderedMessage
		}
		Debug { 
			Write-Debug -Message $RenderedMessage
		}
		Information { 
			Write-Information -MessageData $RenderedMessage
		}
		Warning { 
			Write-Warning -Message $RenderedMessage
		}
		{($_ -eq 'Error') -or ($_ -eq 'Fatal')} { 
			Write-Output -InputObject $RenderedMessage
		}
		Default { 
			Write-Information -MessageData $RenderedMessage
		}
	}
}