using System.Management.Automation;
using PoShLog.Core.Formatting;

namespace PoShLog.Core.Cmdlets.Formatters
{
	/// <summary>
	/// Returns a formatter that writes the Compact Log Event Format (CLEF, one JSON object per line) and can be used
	/// with the File or Console sink. -Rendered writes the rendered message instead of the message template.
	/// </summary>
	[Cmdlet(VerbsCommon.Get, "CompactFormatter")]
	[OutputType(typeof(CompactJsonFormatter))]
	public class GetCompactFormatterCommand : Cmdlet
	{
		[Parameter(Mandatory = false)]
		public SwitchParameter Rendered { get; set; }

		protected override void ProcessRecord()
		{
			WriteObject(new CompactJsonFormatter(Rendered.IsPresent));
		}
	}
}
