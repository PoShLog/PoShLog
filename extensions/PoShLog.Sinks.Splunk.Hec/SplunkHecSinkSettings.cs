using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Management.Automation;
using Serilog.Formatting;
using Serilog.Formatting.Display;
using Serilog.Sinks.Splunk;

namespace PoShLog.Sinks.Splunk.Hec
{
	/// <summary>The HTTP Event Collector endpoint events are sent to.</summary>
	public enum HecEndpoint
	{
		/// <summary>services/collector/event: one JSON event per log event, with level, template and properties.</summary>
		Event,

		/// <summary>services/collector/raw: one text line per log event, rendered with an output template.</summary>
		Raw,
	}

	/// <summary>
	/// What Add-SinkSplunk was given, turned into the request target and formatter of Serilog.Sinks.Splunk. Kept apart
	/// from the cmdlet so the URL rules and the payload choice are testable.
	/// </summary>
	public sealed class SplunkHecSinkSettings
	{
		public const string EventPath = "services/collector/event";
		public const string RawPath = "services/collector/raw";

		/// <summary>The path Serilog.Sinks.Splunk looks for: a URL that contains it is used as it is.</summary>
		public const string CollectorPath = "services/collector";

		public const string DefaultRawOutputTemplate = "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}";

		public string Url { get; set; } = "";
		public HecEndpoint Endpoint { get; set; } = HecEndpoint.Event;
		public string? UriPath { get; set; }
		public string? Index { get; set; }
		public string? Source { get; set; }
		public string? SourceType { get; set; }
		public string? Host { get; set; }
		public IDictionary? Fields { get; set; }
		public string? OutputTemplate { get; set; }
		public IFormatProvider? FormatProvider { get; set; }
		public bool RenderTemplate { get; set; } = true;
		public bool RenderMessage { get; set; } = true;

		/// <summary>
		/// The host and path to hand to the package. It appends the path to the host unless the host's own path already
		/// contains services/collector, so a full collector URL stays as it is. The raw endpoint carries index, source,
		/// sourcetype and host as query parameters, because its body has no envelope.
		/// </summary>
		public (string SplunkHost, string UriPath) ResolveTarget()
		{
			if (!Uri.TryCreate(Url, UriKind.Absolute, out var uri) || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
			{
				throw new ArgumentException($"'{Url}' is not an absolute http or https URL of a Splunk HTTP Event Collector.");
			}
			var query = Endpoint == HecEndpoint.Raw ? RawQuery() : "";
			if (uri.AbsolutePath.Contains(CollectorPath, StringComparison.OrdinalIgnoreCase))
			{
				return (Append(Url, query), EventPath);
			}
			var path = string.IsNullOrWhiteSpace(UriPath) ? (Endpoint == HecEndpoint.Raw ? RawPath : EventPath) : UriPath.Trim('/');
			return (Url, Append(path, query));
		}

		/// <summary>The full URL events are posted to, combined the way the package combines it.</summary>
		public string ResolveRequestUrl()
		{
			var (host, path) = ResolveTarget();
			return new Uri(host.TrimEnd('/')).AbsolutePath.Contains(CollectorPath, StringComparison.OrdinalIgnoreCase)
				? host
				: $"{host.TrimEnd('/')}/{path.TrimStart('/').TrimEnd('/')}";
		}

		/// <summary>The Splunk JSON envelope for the event endpoint, a text line for the raw endpoint.</summary>
		public ITextFormatter CreateFormatter()
		{
			if (Endpoint == HecEndpoint.Raw)
			{
				if (Fields is { Count: > 0 })
				{
					throw new ArgumentException("Fields are indexed fields of the event endpoint; the raw endpoint has no place for them.");
				}
				if (!RenderTemplate || !RenderMessage)
				{
					throw new ArgumentException("DontRenderTemplate and DontRenderMessage shape the event endpoint's JSON; use OutputTemplate for the raw endpoint.");
				}
				return new MessageTemplateTextFormatter(OutputTemplate ?? DefaultRawOutputTemplate, FormatProvider);
			}
			if (OutputTemplate != null)
			{
				throw new ArgumentException("OutputTemplate applies to the raw endpoint; add -Endpoint Raw.");
			}
			var fields = CreateCustomFields();
			return fields == null
				? new SplunkJsonFormatter(RenderTemplate, RenderMessage, FormatProvider, Source, SourceType, Host, Index)
				: new SplunkJsonFormatter(RenderTemplate, RenderMessage, FormatProvider, Source, SourceType, Host, Index, fields);
		}

		/// <summary>Indexed fields from a hashtable: a value is one string, or a list of strings for a list.</summary>
		public CustomFields? CreateCustomFields()
		{
			// The package writes an unterminated "fields" object for an empty list, so none at all is passed then.
			if (Fields is not { Count: > 0 })
			{
				return null;
			}
			var list = new List<CustomField>();
			foreach (DictionaryEntry entry in Fields)
			{
				var name = Text(entry.Key);
				var value = Unwrap(entry.Value);
				list.Add(value is IEnumerable values and not string
					? new CustomField(name, values.Cast<object?>().Select(Text).ToList())
					: new CustomField(name, Text(value)));
			}
			return new CustomFields(list);
		}

		private string RawQuery()
		{
			var parameters = new[] { ("index", Index), ("source", Source), ("sourcetype", SourceType), ("host", Host) }
				.Where(p => !string.IsNullOrWhiteSpace(p.Item2))
				.Select(p => $"{p.Item1}={Uri.EscapeDataString(p.Item2!)}");
			return string.Join("&", parameters);
		}

		private static string Append(string target, string query) =>
			query.Length == 0 ? target : target + (target.Contains('?') ? "&" : "?") + query;

		private static object? Unwrap(object? value) => value is PSObject psObject ? psObject.BaseObject : value;

		private static string Text(object? value) => Convert.ToString(Unwrap(value), CultureInfo.InvariantCulture) ?? "";
	}
}
