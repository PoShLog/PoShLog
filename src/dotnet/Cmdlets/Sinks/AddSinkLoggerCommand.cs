using System.Management.Automation;
using Serilog;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Sinks
{
	/// <summary>
	/// Write log events to a sub-logger, where further processing may occur. Events through the
	/// sub-logger will be constrained by filters and enriched by enrichers that are active in the
	/// parent. A sub-logger cannot be used to log at a more verbose level, but a less verbose
	/// level is possible.
	/// </summary>
	[Cmdlet(VerbsCommon.Add, "SinkLogger")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkLoggerCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		[Parameter(Mandatory = true)]
		public ILogger Logger { get; set; }

		[Parameter(Mandatory = false)]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		protected override void ProcessRecord()
		{
			LoggerConfig.WriteTo.Logger(
				Logger,
				restrictedToMinimumLevel: RestrictedToMinimumLevel);

			WriteObject(LoggerConfig);
		}
	}
}
