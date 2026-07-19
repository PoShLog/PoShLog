using System.Management.Automation;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// Write a log event with the Warning level.
	/// </summary>
	[Cmdlet(VerbsCommunications.Write, "WarningLog", DefaultParameterSetName = "MsgTemp")]
	public class WriteWarningLogCommand : WriteLogCmdletBase
	{
		protected override LogEventLevel Level => LogEventLevel.Warning;
	}
}
