using System.Management.Automation;
using Serilog;

namespace PoShLog.Core.Cmdlets.Enrichers
{
	/// <summary>
	/// Enriches log events with properties from LogContext. Use Push-LogContextProp to add properties.
	/// </summary>
	[Cmdlet(VerbsCommon.Add, "EnrichFromLogContext")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddEnrichFromLogContextCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		protected override void ProcessRecord()
		{
			WriteObject(LoggerConfig.Enrich.FromLogContext());
		}
	}
}
