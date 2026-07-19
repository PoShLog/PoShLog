using System.Management.Automation;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// Write a log event with the Verbose level.
	/// </summary>
	[Cmdlet(VerbsCommunications.Write, "VerboseLog", DefaultParameterSetName = "MsgTemp")]
	public class WriteVerboseLogCommand : WriteLogCmdletBase
	{
		protected override LogEventLevel Level => LogEventLevel.Verbose;
	}
}
