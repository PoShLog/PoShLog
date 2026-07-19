using System.Management.Automation;
using Serilog;

namespace PoShLog.Core.Cmdlets.Enrichers
{
	/// <summary>
	/// Enriches log events with custom property. For example script name.
	/// </summary>
	[Cmdlet(VerbsCommon.Add, "EnrichWithProperty")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddEnrichWithPropertyCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		[Parameter(Mandatory = true)]
		public string Name { get; set; }

		[Parameter(Mandatory = true)]
		public string Value { get; set; }

		[Parameter(Mandatory = false)]
		public bool DestructureObjects { get; set; } = false;

		protected override void ProcessRecord()
		{
			LoggerConfig.Enrich.WithProperty(Name, Value, DestructureObjects);

			WriteObject(LoggerConfig);
		}
	}
}
