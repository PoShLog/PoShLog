using System.Management.Automation;
using Serilog;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.LevelSwitch
{
	/// <summary>
	/// Sets current minimum level of logger configuration, below which no events should be generated.
	/// </summary>
	[Cmdlet(VerbsCommon.Set, "MinimumLevel", DefaultParameterSetName = "Level")]
	[OutputType(typeof(LoggerConfiguration))]
	public class SetMinimumLevelCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "Level")]
		public LogEventLevel Value { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "Level")]
		public SwitchParameter ToPreference { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "Switch")]
		public LoggingLevelSwitch ControlledBy { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "Preference")]
		public SwitchParameter FromPreference { get; set; }

		protected override void ProcessRecord()
		{
			switch (ParameterSetName)
			{
				case "Level":
					ApplyLevel(Value);

					if (ToPreference.IsPresent)
					{
						Utils.LogLevelPreferenceHelper.SetLogLevelToPreference(this, Value);
					}

					break;
				case "Switch":
					LoggerConfig.MinimumLevel.ControlledBy(ControlledBy);
					break;
				case "Preference":
					ApplyFromPreference();
					break;
			}

			WriteObject(LoggerConfig);
		}

		private void ApplyLevel(LogEventLevel value)
		{
			switch (value)
			{
				case LogEventLevel.Verbose:
					LoggerConfig.MinimumLevel.Verbose();
					break;
				case LogEventLevel.Debug:
					LoggerConfig.MinimumLevel.Debug();
					break;
				case LogEventLevel.Warning:
					LoggerConfig.MinimumLevel.Warning();
					break;
				case LogEventLevel.Error:
					LoggerConfig.MinimumLevel.Error();
					break;
				case LogEventLevel.Fatal:
					LoggerConfig.MinimumLevel.Fatal();
					break;
				default:
					LoggerConfig.MinimumLevel.Information();
					break;
			}
		}

		private void ApplyFromPreference()
		{
			var verbosePreference = GetPreference("VerbosePreference");
			var debugPreference = GetPreference("DebugPreference");
			var informationPreference = GetPreference("InformationPreference");
			var warningPreference = GetPreference("WarningPreference");

			if (verbosePreference == "Continue")
			{
				ApplyLevel(LogEventLevel.Verbose);
			}
			else if (debugPreference == "Continue")
			{
				ApplyLevel(LogEventLevel.Debug);
			}
			else if (informationPreference == "Continue")
			{
				ApplyLevel(LogEventLevel.Information);
			}
			else if (warningPreference == "Continue")
			{
				ApplyLevel(LogEventLevel.Warning);
			}
			else
			{
				ApplyLevel(LogEventLevel.Error);
			}
		}

		private string GetPreference(string variableName)
		{
			return GetVariableValue(variableName)?.ToString();
		}
	}
}
