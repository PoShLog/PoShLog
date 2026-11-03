using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using Serilog.Sinks.OpenTelemetry;

namespace PoShLog.Sinks.OpenTelemetry
{
	/// <summary>
	/// What Add-SinkOpenTelemetry was given, turned into the options of Serilog.Sinks.OpenTelemetry. Kept apart from the
	/// cmdlet so the mapping and the environment rules (docs/decisions/0012-otlp-sink-design.md) are testable.
	/// </summary>
	public sealed class OpenTelemetrySinkSettings
	{
		public const string EndpointVariable = "OTEL_EXPORTER_OTLP_ENDPOINT";
		public const string ProtocolVariable = "OTEL_EXPORTER_OTLP_PROTOCOL";
		public const string HeadersVariable = "OTEL_EXPORTER_OTLP_HEADERS";
		public const string ResourceAttributesVariable = "OTEL_RESOURCE_ATTRIBUTES";
		public const string ServiceNameVariable = "OTEL_SERVICE_NAME";

		/// <summary>OTLP/HTTP collector port, the default for <see cref="OtlpProtocol.HttpProtobuf"/>.</summary>
		public const string DefaultHttpEndpoint = "http://localhost:4318";

		/// <summary>OTLP/gRPC collector port, the default for <see cref="OtlpProtocol.Grpc"/>.</summary>
		public const string DefaultGrpcEndpoint = "http://localhost:4317";

		public string? Endpoint { get; set; }
		public OtlpProtocol? Protocol { get; set; }
		public IDictionary? Headers { get; set; }
		public IDictionary? ResourceAttributes { get; set; }
		public string? ServiceName { get; set; }
		public bool IgnoreEnvironment { get; set; }

		/// <summary>Reads an environment variable; replaced in tests.</summary>
		public Func<string, string?> GetEnvironmentVariable { get; set; } = Environment.GetEnvironmentVariable;

		/// <summary>
		/// The protocol in effect: the parameter, else <c>OTEL_EXPORTER_OTLP_PROTOCOL</c>, else OTLP/HTTP (the
		/// OpenTelemetry default). Values other than <c>grpc</c> mean OTLP/HTTP.
		/// </summary>
		public OtlpProtocol ResolveProtocol()
		{
			if (Protocol is { } protocol)
			{
				return protocol;
			}
			var value = IgnoreEnvironment ? null : GetEnvironmentVariable(ProtocolVariable);
			return string.Equals(value?.Trim(), "grpc", StringComparison.OrdinalIgnoreCase) ? OtlpProtocol.Grpc : OtlpProtocol.HttpProtobuf;
		}

		/// <summary>The endpoint the options start with; <c>OTEL_EXPORTER_OTLP_ENDPOINT</c> may still replace a default.</summary>
		public string ResolveEndpoint()
		{
			if (!string.IsNullOrWhiteSpace(Endpoint))
			{
				return Endpoint;
			}
			return ResolveProtocol() == OtlpProtocol.Grpc ? DefaultGrpcEndpoint : DefaultHttpEndpoint;
		}

		/// <summary>Copies the settings into the package's options.</summary>
		public void Apply(OpenTelemetrySinkOptions options)
		{
			options.Endpoint = ResolveEndpoint();
			options.Protocol = ResolveProtocol();
			foreach (var (key, value) in Pairs(Headers))
			{
				options.Headers[key] = value?.ToString() ?? string.Empty;
			}
			foreach (var (key, value) in Pairs(ResourceAttributes))
			{
				options.ResourceAttributes[key] = value ?? string.Empty;
			}
			if (!string.IsNullOrWhiteSpace(ServiceName))
			{
				options.ResourceAttributes["service.name"] = ServiceName;
			}
		}

		/// <summary>
		/// The environment as the package should see it. The package lets <c>OTEL_*</c> variables override code; here a
		/// value given as a parameter wins and the environment only fills in what was not given, the order the
		/// OpenTelemetry SDKs use. With <see cref="IgnoreEnvironment"/> every variable reads as unset.
		/// </summary>
		public Func<string, string?> CreateEnvironmentReader()
		{
			return name =>
			{
				if (IgnoreEnvironment)
				{
					return null;
				}
				var value = GetEnvironmentVariable(name);
				if (string.IsNullOrEmpty(value))
				{
					return value;
				}
				switch (name)
				{
					case EndpointVariable:
						return string.IsNullOrWhiteSpace(Endpoint) ? value : null;
					case ProtocolVariable:
						return Protocol is null ? value : null;
					case HeadersVariable:
						return WithoutKeys(value, Pairs(Headers).Select(p => p.Key), StringComparer.OrdinalIgnoreCase);
					case ResourceAttributesVariable:
						var keys = Pairs(ResourceAttributes).Select(p => p.Key).ToList();
						if (!string.IsNullOrWhiteSpace(ServiceName))
						{
							keys.Add("service.name");
						}
						return WithoutKeys(value, keys, StringComparer.Ordinal);
					case ServiceNameVariable:
						var serviceNameInCode = !string.IsNullOrWhiteSpace(ServiceName) || Pairs(ResourceAttributes).Any(p => p.Key == "service.name");
						return serviceNameInCode ? null : value;
					default:
						return value;
				}
			};
		}

		/// <summary>Drops the <c>key=value</c> items of a comma-separated OTel list whose key is already set in code.</summary>
		internal static string? WithoutKeys(string value, IEnumerable<string> keys, StringComparer comparer)
		{
			var set = new HashSet<string>(keys, comparer);
			if (set.Count == 0)
			{
				return value;
			}
			var kept = value.Split(',')
				.Where(item => item.Trim().Length > 0)
				.Where(item => !set.Contains(item.Split('=', 2)[0].Trim()))
				.ToList();
			return kept.Count == 0 ? null : string.Join(",", kept);
		}

		private static IEnumerable<(string Key, object? Value)> Pairs(IDictionary? dictionary)
		{
			if (dictionary is null)
			{
				yield break;
			}
			foreach (DictionaryEntry entry in dictionary)
			{
				var key = Unwrap(entry.Key)?.ToString();
				if (!string.IsNullOrWhiteSpace(key))
				{
					yield return (key, Unwrap(entry.Value));
				}
			}
		}

		/// <summary>PowerShell may wrap hashtable values in a PSObject; the exporter needs the plain value (6 stays a number).</summary>
		private static object? Unwrap(object? value) => value is PSObject psObject ? psObject.BaseObject : value;
	}
}
