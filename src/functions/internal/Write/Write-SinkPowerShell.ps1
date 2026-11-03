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
			# On 5.1 plain information records and the transcript disagree about visibility.
			if ($InformationPreference -eq 'Continue') {
				Write-Host -Object $RenderedMessage
			}
			elseif ($InformationPreference -notin 'SilentlyContinue', 'Ignore') {
				Write-Information -MessageData $RenderedMessage
			}
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
