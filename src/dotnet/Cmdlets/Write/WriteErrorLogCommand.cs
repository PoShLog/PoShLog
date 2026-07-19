using System.Management.Automation;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// Write a log event with the Error level.
	/// </summary>
	[Cmdlet(VerbsCommunications.Write, "ErrorLog", DefaultParameterSetName = "MsgTemp")]
	public class WriteErrorLogCommand : WriteLogCmdletBase
	{
		protected override LogEventLevel Level => LogEventLevel.Error;
	}
}
