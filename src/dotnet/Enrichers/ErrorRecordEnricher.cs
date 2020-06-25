using PoShLog.Core.Enrichers.Extensions;
using PoShLog.Core.Exceptions;
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
			if (logEvent.Exception is WrapperException wrapperException)
			{
				logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty(ERR_PROPERTY_NAME_FULL, wrapperException.ErrorRecordWrapper));
				logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty(II_PROPERTY_NAME_FULL, wrapperException.ErrorRecordWrapper.InvocationInfoWrapper));
			}
		}
	}
}
