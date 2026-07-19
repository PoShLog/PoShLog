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
					cmdlet.WriteInformation(new InformationRecord(renderedMessage, "PoShLog"));
					break;
				case LogEventLevel.Warning:
					cmdlet.WriteWarning(renderedMessage);
					break;
				default:
					cmdlet.WriteInformation(new InformationRecord(renderedMessage, "PoShLog"));
					break;
			}
		}
	}
}
