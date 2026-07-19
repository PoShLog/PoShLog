using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Serilog;
using Serilog.Core;
using Serilog.Sinks.File;

namespace PoShLog.Core.Extensions
{
	/// <summary>
	/// Reflection helpers used to inspect the private sink tree of a Serilog <see cref="ILogger"/>.
	/// Ported from the original script-based implementation; field names (_sink, _sinks,
	/// _underlyingStream, _currentFile) were verified against Serilog 4.2.0 / Serilog.Sinks.File 6.0.0
	/// and are unchanged from the versions the original implementation targeted.
	/// </summary>
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
