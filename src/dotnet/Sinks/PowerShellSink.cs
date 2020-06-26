using System;
using System.IO;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting;
using Serilog.Formatting.Display;

namespace PoShLog.Core.Sinks
{
	public class PowerShellSink : ILogEventSink
	{
		public const string DEFAULT_OUTPUT_TEMPLATE = "{Message:lj}";

		readonly object _syncRoot = new object();

		public ITextFormatter TextFormatter { get; set; }

		public Action<LogEvent, string> Callback { get; set; }

		public PowerShellSink(Action<LogEvent, string> callback, string outputTemplate = DEFAULT_OUTPUT_TEMPLATE)
		{

			TextFormatter = new MessageTemplateTextFormatter(outputTemplate);
			Callback = callback;
		}

		public void Emit(LogEvent logEvent)
		{
			if (logEvent == null)
			{
				throw new ArgumentNullException(nameof(logEvent));
			}

			StringWriter strWriter = new StringWriter();
			TextFormatter.Format(logEvent, strWriter);
			string renderedMessage = strWriter.ToString();

			lock (_syncRoot)
			{
				Callback(logEvent, renderedMessage);
			}
		}
	}
}