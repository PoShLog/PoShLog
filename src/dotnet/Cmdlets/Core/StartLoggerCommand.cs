using System.Management.Automation;
using PoShLog.Core.Sinks;
using PoShLog.Core.Sinks.Extensions;
using Serilog;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Core
{
	/// <summary>
	/// Creates new instance of logger, that writes to configured sinks.
	/// </summary>
	[Cmdlet(VerbsLifecycle.Start, "Logger", DefaultParameterSetName = "Short")]
	[OutputType(typeof(ILogger))]
	public class StartLoggerCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Full")]
		public LoggerConfiguration LoggerConfig { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "Short")]
		public LogEventLevel MinimumLevel { get; set; } = LogEventLevel.Information;

		[Parameter(Mandatory = false, ParameterSetName = "Short")]
		public SwitchParameter Console { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "Short")]
		public SwitchParameter PowerShell { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "Short")]
		public string FilePath { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "Short")]
		public RollingInterval FileRollingInterval { get; set; } = RollingInterval.Infinite;

		[Parameter(Mandatory = false)]
		public SwitchParameter SetAsDefault { get; set; }

		[Parameter(Mandatory = false)]
		public SwitchParameter PassThru { get; set; }

		protected override void ProcessRecord()
		{
			if (ParameterSetName == "Short")
			{
				LoggerConfig = new LoggerConfiguration();

				switch (MinimumLevel)
				{
					case LogEventLevel.Verbose:
						LoggerConfig.MinimumLevel.Verbose();
						break;
					case LogEventLevel.Debug:
						LoggerConfig.MinimumLevel.Debug();
						break;
					case LogEventLevel.Warning:
						LoggerConfig.MinimumLevel.Warning();
						break;
					case LogEventLevel.Error:
						LoggerConfig.MinimumLevel.Error();
						break;
					case LogEventLevel.Fatal:
						LoggerConfig.MinimumLevel.Fatal();
						break;
					default:
						LoggerConfig.MinimumLevel.Information();
						break;
				}

				var filePathBound = MyInvocation.BoundParameters.ContainsKey(nameof(FilePath));

				// If file path was not passed we setup default PowerShell sink
				if (PowerShell.IsPresent || !filePathBound)
				{
					LoggerConfig.WriteTo.PowerShell(PowerShellSinkWriter.Write);
				}

				if (Console.IsPresent)
				{
					LoggerConfig.WriteTo.Console();
				}

				if (filePathBound)
				{
					LoggerConfig.WriteTo.File(FilePath, rollingInterval: FileRollingInterval);
				}
			}

			var logger = LoggerConfig.CreateLogger();

			if (PassThru.IsPresent)
			{
				if (SetAsDefault.IsPresent)
				{
					Log.Logger = logger;
				}

				WriteObject(logger);
			}
			else
			{
				Log.Logger = logger;
			}
		}
	}
}
