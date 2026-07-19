using System.Linq;
using System.Management.Automation;
using PoShLog.Core.Extensions;
using Serilog;

namespace PoShLog.Core.Cmdlets.Helpers
{
	/// <summary>
	/// Returns the collection of current log files, or an empty array if no file sinks are in use.
	/// Useful when using a rolling log file, e.g. Add-SinkFile -Path 'D:\test-.log' -RollingInterval Day.
	/// </summary>
	[Cmdlet(VerbsCommon.Get, "CurrentLogFiles")]
	[OutputType(typeof(string[]))]
	public class GetCurrentLogFilesCommand : PSCmdlet
	{
		[Parameter(Mandatory = false, ValueFromPipeline = true)]
		public ILogger Logger { get; set; }

		protected override void ProcessRecord()
		{
			var logger = Logger ?? Log.Logger;

			WriteObject(logger.GetCurrentLogFiles().ToArray(), enumerateCollection: true);
		}
	}
}
