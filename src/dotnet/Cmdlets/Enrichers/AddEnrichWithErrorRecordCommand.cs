using System.Management.Automation;
using PoShLog.Core.Enrichers.Extensions;
using Serilog;

namespace PoShLog.Core.Cmdlets.Enrichers
{
	/// <summary>
	/// Enriches log events with ErrorRecord property if available. Use -ErrorRecord parameter on
	/// Write-*Log cmdlets to add ErrorRecord.
	/// </summary>
	[Cmdlet(VerbsCommon.Add, "EnrichWithErrorRecord")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddEnrichWithErrorRecordCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		[Parameter(Mandatory = false)]
		public SwitchParameter DestructureObjects { get; set; }

		protected override void ProcessRecord()
		{
			LoggerConfig.Enrich.WithErrorRecord(DestructureObjects.IsPresent);

			WriteObject(LoggerConfig);
		}
	}
}
