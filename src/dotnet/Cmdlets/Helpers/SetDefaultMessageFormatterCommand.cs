using System.Management.Automation;
using PoShLog.Core.Utils;
using Serilog.Formatting.Display;

namespace PoShLog.Core.Cmdlets.Helpers
{
	/// <summary>
	/// Sets the global text formatter used to render -PassThru output for the Write-*Log cmdlets.
	/// </summary>
	[Cmdlet(VerbsCommon.Set, "DefaultMessageFormatter")]
	public class SetDefaultMessageFormatterCommand : PSCmdlet
	{
		[Parameter(Mandatory = true)]
		public string Template { get; set; }

		protected override void ProcessRecord()
		{
			MessageFormatter.TextFormatter = new MessageTemplateTextFormatter(Template);
		}
	}
}
