using System.IO;
using System.Management.Automation;

namespace PoShLog.Core.Cmdlets.Helpers
{
	/// <summary>
	/// Converts default cmdlets in given script file into logger methods. For example
	/// Write-Information into Write-InfoLog, Write-Error into Write-ErrorLog and so on.
	/// </summary>
	[Cmdlet(VerbsData.Convert, "LogFunctions")]
	public class ConvertLogFunctionsCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public string FilePath { get; set; }

		protected override void ProcessRecord()
		{
			WriteVerbose($"Converting {FilePath}");

			var lines = File.ReadAllLines(FilePath);
			for (var i = 0; i < lines.Length; i++)
			{
				lines[i] = lines[i]
					.Replace("Write-Verbose -Message", "Write-VerboseLog -MessageTemplate")
					.Replace("Write-Verbose ", "Write-VerboseLog ")
					.Replace("Write-Debug -Message", "Write-DebugLog -MessageTemplate")
					.Replace("Write-Debug ", "Write-DebugLog ")
					.Replace("Write-Information -MessageData", "Write-InfoLog -MessageTemplate")
					.Replace("Write-Information ", "Write-InfoLog ")
					.Replace("Write-Host -Object", "Write-InfoLog -MessageTemplate")
					.Replace("Write-Host ", "Write-InfoLog ")
					.Replace("Write-Warning -Message", "Write-WarningLog -MessageTemplate")
					.Replace("Write-Warning ", "Write-WarningLog ")
					.Replace("Write-Error -Message", "Write-ErrorLog -MessageTemplate")
					.Replace("Write-Error ", "Write-ErrorLog ");
			}

			File.WriteAllLines(FilePath, lines);

			WriteVerbose($"{FilePath} successfully converted");
		}
	}
}
