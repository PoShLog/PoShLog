using System.Management.Automation;
using Serilog.Debugging;

namespace PoShLog.Core.Cmdlets.Debugging
{
	/// <summary>
	/// Disables Serilog's SelfLog.
	/// </summary>
	[Cmdlet(VerbsLifecycle.Disable, "SelfLog")]
	public class DisableSelfLogCommand : PSCmdlet
	{
		protected override void ProcessRecord()
		{
			SelfLog.Disable();
		}
	}
}
