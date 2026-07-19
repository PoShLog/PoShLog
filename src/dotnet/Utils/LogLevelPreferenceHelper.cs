using System.Management.Automation;
using Serilog.Events;

namespace PoShLog.Core.Utils
{
	/// <summary>
	/// Equivalent of the internal Set-LogLevelToPreference.ps1 helper: propagates a desired
	/// minimum logging level to the global Verbose/Debug/Information/Warning preference variables.
	/// </summary>
	public static class LogLevelPreferenceHelper
	{
		public static void SetLogLevelToPreference(PSCmdlet cmdlet, LogEventLevel logLevel)
		{
			SetPreference(cmdlet, "VerbosePreference", logLevel <= LogEventLevel.Verbose);
			SetPreference(cmdlet, "DebugPreference", logLevel <= LogEventLevel.Debug);
			SetPreference(cmdlet, "InformationPreference", logLevel <= LogEventLevel.Information);
			SetPreference(cmdlet, "WarningPreference", logLevel <= LogEventLevel.Warning);
		}

		private static void SetPreference(PSCmdlet cmdlet, string variableName, bool continueLogging)
		{
			cmdlet.SessionState.PSVariable.Set("global:" + variableName, continueLogging ? "Continue" : "SilentlyContinue");
		}
	}
}
