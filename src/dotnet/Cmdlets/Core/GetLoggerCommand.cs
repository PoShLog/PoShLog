using System.Management.Automation;
using Serilog;

namespace PoShLog.Core.Cmdlets.Core
{
	/// <summary>
	/// Gets the current logger stored in the static property [Serilog.Log]::Logger.
	/// </summary>
	[Cmdlet(VerbsCommon.Get, "Logger")]
	[OutputType(typeof(ILogger))]
	public class GetLoggerCommand : Cmdlet
	{
		protected override void ProcessRecord()
		{
			WriteObject(Log.Logger);
		}
	}
}
