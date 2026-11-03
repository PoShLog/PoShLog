using System.Management.Automation;
using Serilog;
using Serilog.Events;
using PoShLog.Core.Utils;

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

		/// <summary>A Serilog expression; only events evaluating to true reach this sublogger.</summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string Filter { get; set; }

		[Parameter(Mandatory = false)]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		protected override void ProcessRecord()
		{
			if (Filter != null)
			{
				// Compile during configuration. Evaluation uses no PowerShell runspace on logging threads.
				LoggerConfig.WriteTo.Conditional(ExpressionFilter.Compile(Filter),
					writeTo => writeTo.Logger(Logger, restrictedToMinimumLevel: RestrictedToMinimumLevel));
			}
			else
			{
				LoggerConfig.WriteTo.Logger(Logger, restrictedToMinimumLevel: RestrictedToMinimumLevel);
			}

			WriteObject(LoggerConfig);
		}
	}
}
