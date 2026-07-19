using System;
using System.Management.Automation;
using Serilog.Debugging;

namespace PoShLog.Core.Cmdlets.Debugging
{
	/// <summary>
	/// Enables Serilog's SelfLog, which is used to report internal exceptions and failures.
	/// </summary>
	[Cmdlet(VerbsLifecycle.Enable, "SelfLog")]
	public class EnableSelfLogCommand : PSCmdlet
	{
		[Parameter(Mandatory = false)]
		public Action<string> MessageFunc { get; set; }

		protected override void ProcessRecord()
		{
			var messageFunc = MessageFunc ?? DefaultMessageFunc;

			SelfLog.Enable(messageFunc);
		}

		// SelfLog callbacks can fire at any point after this cmdlet has finished running, long
		// after the pipeline that invoked Enable-SelfLog has ended. PSCmdlet.WriteWarning is only
		// valid while its own pipeline is executing, so the default callback writes to
		// Console.Error instead of trying (and failing) to reuse this cmdlet's runtime later.
		private static void DefaultMessageFunc(string message)
		{
			Console.Error.WriteLine(message);
		}
	}
}
