using System.Management.Automation;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.LevelSwitch
{
	/// <summary>
	/// Creates instance of LoggingLevelSwitch at the initial minimum level.
	/// </summary>
	[Cmdlet(VerbsCommon.New, "LevelSwitch")]
	[OutputType(typeof(LoggingLevelSwitch))]
	public class NewLevelSwitchCommand : PSCmdlet
	{
		[Parameter(Mandatory = false)]
		public LogEventLevel MinimumLevel { get; set; } = LogEventLevel.Information;

		[Parameter(Mandatory = false)]
		public SwitchParameter ToPreference { get; set; }

		protected override void ProcessRecord()
		{
			var levelSwitch = new LoggingLevelSwitch { MinimumLevel = MinimumLevel };

			if (ToPreference.IsPresent)
			{
				Utils.LogLevelPreferenceHelper.SetLogLevelToPreference(this, MinimumLevel);
			}

			WriteObject(levelSwitch);
		}
	}
}
