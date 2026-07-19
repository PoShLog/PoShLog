using System.Management.Automation;
using Serilog;

namespace PoShLog.Core.Cmdlets.Core
{
	/// <summary>
	/// Creates instance of Serilog LoggerConfiguration allowing method chaining.
	/// </summary>
	[Cmdlet(VerbsCommon.New, "Logger")]
	[OutputType(typeof(LoggerConfiguration))]
	public class NewLoggerCommand : Cmdlet
	{
		protected override void ProcessRecord()
		{
			WriteObject(new LoggerConfiguration());
		}
	}
}
