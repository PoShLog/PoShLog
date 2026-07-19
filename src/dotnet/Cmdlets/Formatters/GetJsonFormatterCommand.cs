using System.Management.Automation;
using Serilog.Formatting.Json;

namespace PoShLog.Core.Cmdlets.Formatters
{
	/// <summary>
	/// Returns new instance of Serilog.Formatting.Json.JsonFormatter that can be used with File or
	/// Console sink.
	/// </summary>
	[Cmdlet(VerbsCommon.Get, "JsonFormatter")]
	[OutputType(typeof(JsonFormatter))]
	public class GetJsonFormatterCommand : Cmdlet
	{
		protected override void ProcessRecord()
		{
			WriteObject(new JsonFormatter());
		}
	}
}
