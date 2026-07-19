using System.Management.Automation;
using Serilog;

namespace PoShLog.Core.Cmdlets.Core
{
	/// <summary>
	/// Resets Logger to the default and disposes the original if possible.
	/// </summary>
	[Cmdlet(VerbsCommon.Close, "Logger")]
	public class CloseLoggerCommand : PSCmdlet
	{
		[Parameter(Mandatory = false, ValueFromPipeline = true)]
		public ILogger Logger { get; set; }

		protected override void ProcessRecord()
		{
			if (MyInvocation.BoundParameters.ContainsKey(nameof(Logger)))
			{
				(Logger as System.IDisposable)?.Dispose();
			}
			else
			{
				Log.CloseAndFlush();
			}
		}
	}
}
