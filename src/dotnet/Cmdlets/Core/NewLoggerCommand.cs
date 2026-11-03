using System.Management.Automation;
using Serilog;
using PoShLog.Core.Utils;

namespace PoShLog.Core.Cmdlets.Core
{
	/// <summary>
	/// Creates instance of Serilog LoggerConfiguration allowing method chaining.
	/// </summary>
	[Cmdlet(VerbsCommon.New, "Logger")]
	[OutputType(typeof(LoggerConfiguration))]
	public class NewLoggerCommand : PSCmdlet
	{
		/// <summary>Read the Serilog section of a JSON file once, relative to the PowerShell location.</summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string ConfigurationPath { get; set; }

		protected override void ProcessRecord()
		{
			var logger = new LoggerConfiguration();
			if (ConfigurationPath != null)
			{
				try
				{
					JsonLoggerConfiguration.Apply(logger, ProviderFilePath.Resolve(SessionState, ConfigurationPath), SessionState);
				}
				catch
				{
					// Configuration methods can acquire sink resources before a later entry fails.
					// Dispose the partial pipeline without replacing the original configuration error.
					try { logger.CreateLogger().Dispose(); } catch { }
					throw;
				}
			}
			WriteObject(logger);
		}
	}
}
