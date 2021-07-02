using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Serilog;
using Serilog.Core;
using Serilog.Sinks.File;

namespace PoShLog.Core.Extensions
{
	public static class LoggerExtensions
	{
		public static List<string> GetCurrentLogFiles(this ILogger logger)
		{
			var filesList = new List<string>();
			if (logger.GetPrivateFieldValue("_sink").GetPrivateFieldValue("_sinks") is ILogEventSink[] sinks)
			{
				foreach (var logEventSink in sinks)
				{
					FileStream stream;
					if (logEventSink is FileSink fileSink)
					{
						stream = fileSink.GetPrivateFieldValue("_underlyingStream") as FileStream;
					}
					else
					{
						stream = logEventSink.GetPrivateFieldValue("_currentFile").GetPrivateFieldValue("_underlyingStream") as FileStream;
					}

					if (stream != null)
					{
						filesList.Add(stream.Name);
					}
				}
			}

			return filesList;
		}

		public static object GetPrivateFieldValue(this object obj, string fieldName)
		{
			if (obj == null)
			{
				return null;
			}

			var field = obj
				.GetType()
				.GetField(fieldName, BindingFlags.NonPublic | BindingFlags.Instance);

			return field?.GetValue(obj);
		}
	}
}
