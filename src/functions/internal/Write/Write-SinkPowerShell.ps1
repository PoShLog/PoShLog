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
		Default { 
			# PSHOST records are displayed and transcribed consistently on 5.1 and 7.
			Write-Host -Object $RenderedMessage -ForegroundColor Red
		}
	}
}
