using System.Management.Automation;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// For backwards compatibility and also shorthand for Write-InformationLog.
	/// </summary>
	[Cmdlet(VerbsCommunications.Write, "InfoLog", DefaultParameterSetName = "MsgTemp")]
	public class WriteInfoLogCommand : WriteInformationLogCommand
	{
	}
}
