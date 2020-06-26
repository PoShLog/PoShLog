using PoShLog.Core.Exceptions;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Core.Enrichers
{
	public class ErrorRecordEnricher : ILogEventEnricher
	{
		public const string ERR_PROPERTY_NAME_FULL = "ErrorRecord";
		public const string II_PROPERTY_NAME_FULL = "InvocationInfo";

		public bool DestructureObjects { get; }

		public ErrorRecordEnricher()
		{

		}

		public ErrorRecordEnricher(bool destructureObjects)
		{
			DestructureObjects = destructureObjects;
		}

		public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
		{
			if (logEvent.Exception is WrapperException wrapperException)
			{
				logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty(ERR_PROPERTY_NAME_FULL, wrapperException.ErrorRecordWrapper, DestructureObjects));
				logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty(II_PROPERTY_NAME_FULL, wrapperException.ErrorRecordWrapper.InvocationInfoWrapper, DestructureObjects));
			}
		}
	}
}
