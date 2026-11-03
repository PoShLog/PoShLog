using System;
using System.Management.Automation;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting;
using Serilog.Sinks.SystemConsole.Themes;

namespace PoShLog.Core.Cmdlets.Sinks
{
	/// <summary>
	/// Writes log events to console host.
	/// </summary>
	[Cmdlet(VerbsCommon.Add, "SinkConsole", DefaultParameterSetName = "Default")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkConsoleCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		[Parameter(Mandatory = false)]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		[Parameter(Mandatory = false)]
		public string OutputTemplate { get; set; } = "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{ErrorRecord}{Exception}";

		[Parameter(Mandatory = false)]
		public IFormatProvider FormatProvider { get; set; }

		[Parameter(Mandatory = false)]
		public LoggingLevelSwitch LevelSwitch { get; set; }

		[Parameter(Mandatory = false)]
		public LogEventLevel? StandardErrorFromLevel { get; set; }

		[Parameter(Mandatory = false)]
		public ConsoleTheme Theme { get; set; }

		/// <summary>Apply the selected theme even when console output is redirected.</summary>
		[Parameter(ParameterSetName = "Default")]
		public SwitchParameter ApplyThemeToRedirectedOutput { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "Formatter")]
		public ITextFormatter Formatter { get; set; }

		protected override void ProcessRecord()
		{
			switch (ParameterSetName)
			{
				case "Formatter":
					LoggerConfig.WriteTo.Console(
						Formatter,
						restrictedToMinimumLevel: RestrictedToMinimumLevel,
						levelSwitch: LevelSwitch,
						standardErrorFromLevel: StandardErrorFromLevel);
					break;
				default:
					LoggerConfig.WriteTo.Console(
						restrictedToMinimumLevel: RestrictedToMinimumLevel,
						outputTemplate: OutputTemplate,
						formatProvider: FormatProvider,
						levelSwitch: LevelSwitch,
						standardErrorFromLevel: StandardErrorFromLevel,
						theme: Theme,
						applyThemeToRedirectedOutput: ApplyThemeToRedirectedOutput.IsPresent);
					break;
			}

			WriteObject(LoggerConfig);
		}
	}
}
