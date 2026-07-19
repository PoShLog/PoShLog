using System.Management.Automation;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// Write a log event with the Debug level.
	/// </summary>
	[Cmdlet(VerbsCommunications.Write, "DebugLog", DefaultParameterSetName = "MsgTemp")]
	public class WriteDebugLogCommand : WriteLogCmdletBase
	{
		protected override LogEventLevel Level => LogEventLevel.Debug;
	}
}
