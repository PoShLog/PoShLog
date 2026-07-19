using System.Management.Automation;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// Write a log event with the Information level.
	/// </summary>
	[Cmdlet(VerbsCommunications.Write, "InformationLog", DefaultParameterSetName = "MsgTemp")]
	public class WriteInformationLogCommand : WriteLogCmdletBase
	{
		protected override LogEventLevel Level => LogEventLevel.Information;
	}
}
