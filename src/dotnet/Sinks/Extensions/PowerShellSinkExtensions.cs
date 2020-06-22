using System;
using Serilog;
using Serilog.Configuration;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Core.Sinks.Extensions
{
	public static class PowerShellSinkExtensions
	{
		public static LoggerConfiguration PowerShell(this LoggerSinkConfiguration loggerConfiguration, Action<LogEvent, string> callback, LogEventLevel restrictedToMinimumLevel = LevelAlias.Minimum, string outputTemplate = PowerShellSink.DEFAULT_OUTPUT_TEMPLATE, LoggingLevelSwitch levelSwitch = null)
		{
			return loggerConfiguration.Sink(new PowerShellSink(callback, outputTemplate), restrictedToMinimumLevel, levelSwitch);
		}
	}
}
