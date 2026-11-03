using System;
using System.Globalization;
using System.IO;
using System.Linq;
using Serilog.Events;
using Serilog.Formatting;
using Serilog.Formatting.Json;
using Serilog.Parsing;

namespace PoShLog.Core.Formatting
{
	/// <summary>
	/// Writes log events in the Compact Log Event Format (CLEF, https://clef-json.org/), one JSON object per line.
	/// The output matches Serilog.Formatting.Compact's CompactJsonFormatter and RenderedCompactJsonFormatter;
	/// PoShLog ships its own copy because loading that package into the shared load context would break v2
	/// extensions that bring an older version of it (see docs/decisions/0007-clef-formatter-in-core.md).
	/// </summary>
	public sealed class CompactJsonFormatter : ITextFormatter
	{
		private readonly JsonValueFormatter _valueFormatter;

		/// <param name="rendered">Write the rendered message (@m) and an event id (@i) instead of the template (@mt).</param>
		/// <param name="valueFormatter">Formats property values; defaults to a JsonValueFormatter with a "$type" tag.</param>
		public CompactJsonFormatter(bool rendered = false, JsonValueFormatter valueFormatter = null)
		{
			Rendered = rendered;
			_valueFormatter = valueFormatter ?? new JsonValueFormatter(typeTagName: "$type");
		}

		public bool Rendered { get; }

		public void Format(LogEvent logEvent, TextWriter output)
		{
			if (logEvent == null)
			{
				throw new ArgumentNullException(nameof(logEvent));
			}

			if (output == null)
			{
				throw new ArgumentNullException(nameof(output));
			}

			output.Write("{\"@t\":\"");
			output.Write(logEvent.Timestamp.UtcDateTime.ToString("O"));
			output.Write('"');

			if (Rendered)
			{
				output.Write(",\"@m\":");
				JsonValueFormatter.WriteQuotedJsonString(logEvent.MessageTemplate.Render(logEvent.Properties, CultureInfo.InvariantCulture), output);
				output.Write(",\"@i\":\"");
				output.Write(ComputeEventId(logEvent.MessageTemplate.Text).ToString("x8", CultureInfo.InvariantCulture));
				output.Write('"');
			}
			else
			{
				output.Write(",\"@mt\":");
				JsonValueFormatter.WriteQuotedJsonString(logEvent.MessageTemplate.Text, output);
				WriteRenderings(logEvent, output);
			}

			if (logEvent.Level != LogEventLevel.Information)
			{
				output.Write(",\"@l\":\"");
				output.Write(logEvent.Level);
				output.Write('"');
			}

			if (logEvent.Exception != null)
			{
				output.Write(",\"@x\":");
				JsonValueFormatter.WriteQuotedJsonString(logEvent.Exception.ToString(), output);
			}

			if (logEvent.TraceId != null)
			{
				output.Write(",\"@tr\":\"");
				output.Write(logEvent.TraceId.Value.ToHexString());
				output.Write('"');
			}

			if (logEvent.SpanId != null)
			{
				output.Write(",\"@sp\":\"");
				output.Write(logEvent.SpanId.Value.ToHexString());
				output.Write('"');
			}

			foreach (var property in logEvent.Properties)
			{
				// CLEF reserves names that start with '@'; a user property escapes it by doubling.
				var name = property.Key.Length > 0 && property.Key[0] == '@' ? "@" + property.Key : property.Key;
				output.Write(',');
				JsonValueFormatter.WriteQuotedJsonString(name, output);
				output.Write(':');
				_valueFormatter.Format(property.Value, output);
			}

			output.Write('}');
			output.WriteLine();
		}

		/// <summary>Writes @r: the renderings of tokens that carry a format string, in template order.</summary>
		private static void WriteRenderings(LogEvent logEvent, TextWriter output)
		{
			var tokensWithFormat = logEvent.MessageTemplate.Tokens.OfType<PropertyToken>().Where(token => token.Format != null).ToList();
			if (tokensWithFormat.Count == 0)
			{
				return;
			}

			output.Write(",\"@r\":[");
			var delimiter = "";
			foreach (var token in tokensWithFormat)
			{
				output.Write(delimiter);
				delimiter = ",";
				using (var rendering = new StringWriter())
				{
					token.Render(logEvent.Properties, rendering, CultureInfo.InvariantCulture);
					JsonValueFormatter.WriteQuotedJsonString(rendering.ToString(), output);
				}
			}

			output.Write(']');
		}

		/// <summary>The Jenkins one-at-a-time hash of the message template, as Serilog.Formatting.Compact computes @i.</summary>
		public static uint ComputeEventId(string messageTemplate)
		{
			unchecked
			{
				uint hash = 0;
				foreach (var c in messageTemplate)
				{
					hash += c;
					hash += hash << 10;
					hash ^= hash >> 6;
				}

				hash += hash << 3;
				hash ^= hash >> 11;
				hash += hash << 15;
				return hash;
			}
		}
	}
}
