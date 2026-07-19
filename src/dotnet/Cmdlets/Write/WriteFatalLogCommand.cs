using System.Management.Automation;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// Write a log event with the Fatal level.
	/// </summary>
	[Cmdlet(VerbsCommunications.Write, "FatalLog", DefaultParameterSetName = "MsgTemp")]
	public class WriteFatalLogCommand : WriteLogCmdletBase
	{
		protected override LogEventLevel Level => LogEventLevel.Fatal;
	}
}
