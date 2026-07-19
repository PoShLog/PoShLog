using System;
using System.IO;
using Serilog;
using Serilog.Events;
using Serilog.Formatting.Display;

namespace PoShLog.Core.Utils
{
	/// <summary>
	/// Equivalent of the internal Get-FormattedMessage.ps1 helper: renders a message template with
	/// the same text formatter used for -PassThru output on the Write-*Log cmdlets.
	/// </summary>
	public static class MessageFormatter
	{
		private static readonly MessageTemplateTextFormatter DefaultFormatter = new MessageTemplateTextFormatter("{Message:lj}");

		/// <summary>
		/// Global text formatter used to render -PassThru output for the Write-*Log cmdlets.
		/// Set via Set-DefaultMessageFormatter; falls back to the built-in "{Message:lj}" template.
		/// </summary>
		public static MessageTemplateTextFormatter TextFormatter { get; set; }

		public static string Format(ILogger logger, LogEventLevel level, string messageTemplate, object[] propertyValues, Exception exception)
		{
			if (logger.BindMessageTemplate(messageTemplate, propertyValues, out var parsedTemplate, out var boundProperties))
			{
				var logEvent = new LogEvent(DateTimeOffset.Now, level, exception, parsedTemplate, boundProperties);
				using (var writer = new StringWriter())
				{
					var formatter = TextFormatter ?? DefaultFormatter;
					formatter.Format(logEvent, writer);
					return writer.ToString();
				}
			}

			return null;
		}
	}
}
