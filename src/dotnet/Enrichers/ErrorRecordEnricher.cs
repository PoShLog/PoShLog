using System.Management.Automation;
using PoShLog.Core.Enrichers.Extensions;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Core.Enrichers
{
	public class ErrorRecordEnricher : ILogEventEnricher
	{
		public const string ERR_PROPERTY_NAME_FULL = "ErrorRecord";
		public const string II_PROPERTY_NAME_FULL = "InvocationInfo";

		public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
		{
			if (logEvent.Exception is RuntimeException runtimeException)
			{
				var errRecord = runtimeException.ErrorRecord;
				var invocationInfo = errRecord.InvocationInfo;

				var errorRecordProperty = propertyFactory.CreateProperty(ERR_PROPERTY_NAME_FULL, errRecord.ToTable());
				logEvent.AddPropertyIfAbsent(errorRecordProperty);

				var invocationInfoProperty = propertyFactory.CreateProperty(II_PROPERTY_NAME_FULL, invocationInfo.ToTable());
				logEvent.AddPropertyIfAbsent(invocationInfoProperty);
			}
		}
	}
}
