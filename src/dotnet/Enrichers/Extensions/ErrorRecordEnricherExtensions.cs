using System;
using Serilog;
using Serilog.Configuration;
using Serilog.Events;

namespace PoShLog.Core.Enrichers.Extensions
{
	public static class ErrorRecordEnricherExtensions
	{
		public static LoggerConfiguration WithErrorRecord(this LoggerEnrichmentConfiguration loggerConfiguration)
		{
			return loggerConfiguration.With(new ErrorRecordEnricher());
		}
	}
}
