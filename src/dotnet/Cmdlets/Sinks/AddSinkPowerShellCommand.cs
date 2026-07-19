using System.Management.Automation;
using PoShLog.Core.Sinks;
using PoShLog.Core.Sinks.Extensions;
using Serilog;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Sinks
{
	/// <summary>
	/// Writes log events to the PowerShell host.
	/// </summary>
	[Cmdlet(VerbsCommon.Add, "SinkPowerShell")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkPowerShellCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		[Parameter(Mandatory = false)]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		[Parameter(Mandatory = false)]
		public string OutputTemplate { get; set; } = "{Message:lj}{ErrorRecord}";

		[Parameter(Mandatory = false)]
		public LoggingLevelSwitch LevelSwitch { get; set; }

		protected override void ProcessRecord()
		{
			LoggerConfig.WriteTo.PowerShell(
				PowerShellSinkWriter.Write,
				RestrictedToMinimumLevel,
				OutputTemplate,
				LevelSwitch);

			WriteObject(LoggerConfig);
		}
	}
}
