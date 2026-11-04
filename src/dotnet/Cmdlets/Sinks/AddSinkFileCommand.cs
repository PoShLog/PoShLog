using System;
using System.Management.Automation;
using System.Text;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting;
using PoShLog.Core.Utils;

namespace PoShLog.Core.Cmdlets.Sinks
{
	/// <summary>
	/// Write log events to a FileSystem path resolved against the current PowerShell location.
	/// </summary>
	[Cmdlet(VerbsCommon.Add, "SinkFile", DefaultParameterSetName = "Default")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkFileCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; }

		/// <summary>FileSystem path, including PSDrives. Relative paths use the current PowerShell location.</summary>
		[Parameter(Mandatory = true)]
		[ValidateNotNullOrEmpty]
		public string Path { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "Formatter")]
		public ITextFormatter Formatter { get; set; }

		[Parameter(Mandatory = false)]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		[Parameter(Mandatory = false)]
		public string OutputTemplate { get; set; } = "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{ErrorRecord}{Exception}";

		[Parameter(Mandatory = false, ParameterSetName = "Default")]
		public IFormatProvider FormatProvider { get; set; }

		[Parameter(Mandatory = false)]
		public long? FileSizeLimitBytes { get; set; } = 1073741824L;

		[Parameter(Mandatory = false)]
		public LoggingLevelSwitch LevelSwitch { get; set; }

		[Parameter(Mandatory = false)]
		public SwitchParameter Buffered { get; set; }

		[Parameter(Mandatory = false)]
		public SwitchParameter Shared { get; set; }

		[Parameter(Mandatory = false)]
		public TimeSpan? FlushToDiskInterval { get; set; }

		[Parameter(Mandatory = false)]
		public RollingInterval RollingInterval { get; set; } = RollingInterval.Infinite;

		[Parameter(Mandatory = false)]
		public SwitchParameter RollOnFileSizeLimit { get; set; }

		[Parameter(Mandatory = false)]
		public int? RetainedFileCountLimit { get; set; } = 31;

		[Parameter(Mandatory = false)]
		public Encoding Encoding { get; set; }

		[Parameter(Mandatory = false)]
		public Serilog.Sinks.File.FileLifecycleHooks Hooks { get; set; }

		protected override void ProcessRecord()
		{
			var filePath = ProviderFilePath.Resolve(SessionState, Path);
			switch (ParameterSetName)
			{
				case "Formatter":
					LoggerConfig.WriteTo.File(
						Formatter,
						filePath,
						restrictedToMinimumLevel: RestrictedToMinimumLevel,
						fileSizeLimitBytes: FileSizeLimitBytes,
						levelSwitch: LevelSwitch,
						buffered: Buffered.IsPresent,
						shared: Shared.IsPresent,
						flushToDiskInterval: FlushToDiskInterval,
						rollingInterval: RollingInterval,
						rollOnFileSizeLimit: RollOnFileSizeLimit.IsPresent,
						retainedFileCountLimit: RetainedFileCountLimit,
						encoding: Encoding,
						hooks: Hooks);
					break;
				default:
					LoggerConfig.WriteTo.File(
						filePath,
						restrictedToMinimumLevel: RestrictedToMinimumLevel,
						outputTemplate: OutputTemplate,
						formatProvider: FormatProvider,
						fileSizeLimitBytes: FileSizeLimitBytes,
						levelSwitch: LevelSwitch,
						buffered: Buffered.IsPresent,
						shared: Shared.IsPresent,
						flushToDiskInterval: FlushToDiskInterval,
						rollingInterval: RollingInterval,
						rollOnFileSizeLimit: RollOnFileSizeLimit.IsPresent,
						retainedFileCountLimit: RetainedFileCountLimit,
						encoding: Encoding,
						hooks: Hooks);
					break;
			}

			WriteObject(LoggerConfig);
		}
	}
}
