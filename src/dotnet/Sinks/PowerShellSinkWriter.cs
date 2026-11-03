using System;
using System.Management.Automation;
using PoShLog.Core.Utils;
using Serilog.Events;

namespace PoShLog.Core.Sinks
{
	/// <summary>
	/// Equivalent of the internal Write-SinkPowerShell.ps1 helper used as the callback for the
	/// PowerShell sink (see AddSinkPowerShellCommand / StartLoggerCommand short mode). Routes
	/// rendered log messages to the write streams of whichever cmdlet is currently executing.
	/// </summary>
	public static class PowerShellSinkWriter
	{
		/// <summary>Source of every information record the PowerShell sink writes.</summary>
		public const string InformationSource = "PoShLog";

		/// <summary>
		/// The tag Write-Host uses; PowerShell shows a record carrying it regardless of $InformationPreference,
		/// writes it to the transcript, and still lets 6> redirect it.
		/// </summary>
		private const string HostTag = "PSHOST";

		public static void Write(LogEvent logEvent, string renderedMessage)
		{
			var cmdlet = PSCmdletContext.Current;
			if (cmdlet == null)
			{
				return;
			}

			switch (logEvent.Level)
			{
				case LogEventLevel.Verbose:
					cmdlet.WriteVerbose(renderedMessage);
					break;
				case LogEventLevel.Debug:
					cmdlet.WriteDebug(renderedMessage);
					break;
				case LogEventLevel.Information:
					cmdlet.WriteInformation(new InformationRecord(renderedMessage, InformationSource));
					break;
				case LogEventLevel.Warning:
					cmdlet.WriteWarning(renderedMessage);
					break;
				default:
					cmdlet.WriteInformation(CreateDisplayedRecord(cmdlet, renderedMessage));
					break;
			}
		}

		/// <summary>
		/// Error and Fatal events are always displayed, as v2 did with -InformationAction Continue, so the console and
		/// the transcript show the same lines (issue #45). They are not written as ErrorRecords: Write-ErrorLog must not
		/// stop a script that runs with $ErrorActionPreference = 'Stop'. An explicit -InformationAction on the Write-*Log
		/// call still decides; see docs/decisions/0008-powershell-sink-streams.md.
		/// </summary>
		private static InformationRecord CreateDisplayedRecord(Cmdlet cmdlet, string renderedMessage)
		{
			var message = new HostInformationMessage { Message = renderedMessage, ForegroundColor = ConsoleColor.Red };
			var record = new InformationRecord(message, InformationSource);

			var explicitAction = cmdlet is PSCmdlet psCmdlet && psCmdlet.MyInvocation.BoundParameters.ContainsKey("InformationAction");
			if (!explicitAction)
			{
				record.Tags.Add(HostTag);
			}

			return record;
		}
	}
}
