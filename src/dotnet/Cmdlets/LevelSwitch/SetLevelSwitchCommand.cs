using System.Management.Automation;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.LevelSwitch
{
	/// <summary>
	/// Sets minimum level of given level switch.
	/// </summary>
	[Cmdlet(VerbsCommon.Set, "LevelSwitch")]
	[OutputType(typeof(LoggingLevelSwitch))]
	public class SetLevelSwitchCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggingLevelSwitch LevelSwitch { get; set; }

		[Parameter(Mandatory = true)]
		public LogEventLevel MinimumLevel { get; set; }

		[Parameter(Mandatory = false)]
		public SwitchParameter ToPreference { get; set; }

		[Parameter(Mandatory = false)]
		public SwitchParameter PassThru { get; set; }

		protected override void ProcessRecord()
		{
			LevelSwitch.MinimumLevel = MinimumLevel;

			if (ToPreference.IsPresent)
			{
				Utils.LogLevelPreferenceHelper.SetLogLevelToPreference(this, MinimumLevel);
			}

			if (PassThru.IsPresent)
			{
				WriteObject(LevelSwitch);
			}
		}
	}
}
