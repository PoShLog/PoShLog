using System.Management.Automation;
using Serilog;

namespace PoShLog.Core.Cmdlets.Core
{
	/// <summary>
	/// Sets given logger as the static property [Serilog.Log]::Logger that is globally available.
	/// </summary>
	[Cmdlet(VerbsCommon.Set, "Logger")]
	public class SetLoggerCommand : Cmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public ILogger Logger { get; set; }

		protected override void ProcessRecord()
		{
			Log.Logger = Logger;
		}
	}
}
