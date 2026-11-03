using System;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Channels;
using Elastic.CommonSchema.Serilog;
using Elastic.Ingest.Elasticsearch;
using Elastic.Ingest.Elasticsearch.DataStreams;
using Elastic.Serilog.Sinks;
using Elastic.Transport;
using Serilog.Debugging;

namespace PoShLog.Sinks.Elastic
{
	/// <summary>
	/// What Add-SinkElasticsearch was given, turned into the sink and transport options of Elastic.Serilog.Sinks. Kept apart
	/// from the cmdlet so the validation and the defaults are testable.
	/// </summary>
	public sealed class ElasticSinkSettings
	{
		public const string DefaultDataStream = "logs-poshlog-default";

		public const int DefaultBatchSizeLimit = 1000;

		public static readonly TimeSpan DefaultBatchInterval = TimeSpan.FromSeconds(2);

		public const int DefaultQueueLimit = 100000;

		/// <summary>Elastic.Channels ignores a shorter buffer lifetime and keeps its default of five seconds.</summary>
		public static readonly TimeSpan MinimumBatchInterval = TimeSpan.FromSeconds(1);

		// Each part is lowercase and has no '-', which separates the parts; the type and dataset name the index template.
		private static readonly Regex DataStreamPart = new("^[a-z0-9][a-z0-9_.]*$", RegexOptions.CultureInvariant);

		private static readonly Regex Fingerprint = new("^([0-9A-Fa-f]{2}:?){31}[0-9A-Fa-f]{2}$", RegexOptions.CultureInvariant);

		public Uri[]? Nodes { get; set; }
		public string? CloudId { get; set; }
		public string? ApiKey { get; set; }
		public string? UserName { get; set; }
		public string? Password { get; set; }
		public string DataStream { get; set; } = DefaultDataStream;
		public BootstrapMethod BootstrapMethod { get; set; } = BootstrapMethod.None;
		public string? IlmPolicy { get; set; }
		public string? CertificateFingerprint { get; set; }
		public IFormatProvider? FormatProvider { get; set; }
		public bool IncludeHost { get; set; } = true;
		public bool IncludeProcess { get; set; } = true;
		public bool IncludeUser { get; set; } = true;
		public TimeSpan BatchInterval { get; set; } = DefaultBatchInterval;
		public int BatchSizeLimit { get; set; } = DefaultBatchSizeLimit;
		public int QueueLimit { get; set; } = DefaultQueueLimit;

		/// <summary>Splits "type-dataset-namespace" into the data stream name.</summary>
		public static DataStreamName ParseDataStream(string value)
		{
			var parts = (value ?? "").Split('-');
			if (parts.Length != 3 || !parts.All(DataStreamPart.IsMatch))
			{
				throw new ArgumentException(
					$"'{value}' is not a data stream name. Use type-dataset-namespace in lowercase, such as {DefaultDataStream}; the parts contain no '-'.");
			}
			return new DataStreamName(parts[0], parts[1], parts[2]);
		}

		/// <summary>Checks the combination of options before anything connects.</summary>
		public void Validate()
		{
			var hasNodes = Nodes is { Length: > 0 };
			if (hasNodes == !string.IsNullOrWhiteSpace(CloudId))
			{
				throw new ArgumentException("Pass either -Node or -CloudId.");
			}
			foreach (var node in Nodes ?? [])
			{
				if (!node.IsAbsoluteUri || (node.Scheme != Uri.UriSchemeHttp && node.Scheme != Uri.UriSchemeHttps))
				{
					throw new ArgumentException($"'{node}' is not an absolute http or https URL of an Elasticsearch node.");
				}
			}
			if (ApiKey != null && UserName != null)
			{
				throw new ArgumentException("Use either -ApiKey or -Credential.");
			}
			if (!hasNodes && ApiKey == null && UserName == null)
			{
				throw new ArgumentException("-CloudId needs -ApiKey or -Credential.");
			}
			if (CertificateFingerprint != null && !Fingerprint.IsMatch(CertificateFingerprint))
			{
				throw new ArgumentException(
					$"'{CertificateFingerprint}' is not a SHA-256 certificate fingerprint (64 hexadecimal digits, colons allowed).");
			}
			if (BatchInterval < MinimumBatchInterval)
			{
				throw new ArgumentException($"BatchInterval must be at least 1 second, not {BatchInterval}; the Elastic channel would ignore it.");
			}
			if (IlmPolicy != null && BootstrapMethod == BootstrapMethod.None)
			{
				throw new ArgumentException("-IlmPolicy is applied by the bootstrap; add -BootstrapMethod Silent or Failure.");
			}
			ParseDataStream(DataStream);
		}

		/// <summary>The data stream, bootstrap, ECS fields and buffer of the sink.</summary>
		public void ConfigureSink(ElasticsearchSinkOptions options)
		{
			options.DataStream = ParseDataStream(DataStream);
			options.BootstrapMethod = BootstrapMethod;
			if (IlmPolicy != null)
			{
				options.IlmPolicy = IlmPolicy;
			}
			options.TextFormatting = new EcsTextFormatterConfiguration<LogEventEcsDocument>
			{
				IncludeHost = IncludeHost,
				IncludeProcess = IncludeProcess,
				IncludeUser = IncludeUser,
				MessageFormatProvider = FormatProvider,
			};
			options.ConfigureChannel = channel =>
			{
				channel.BufferOptions = new()
				{
					InboundBufferMaxSize = QueueLimit,
					OutboundBufferMaxSize = BatchSizeLimit,
					OutboundBufferMaxLifetime = BatchInterval,
					// The package waits when the buffer is full, which would stall the script; the other PoShLog sinks drop.
					BoundedChannelFullMode = BoundedChannelFullMode.DropWrite,
				};
				// The innermost exception names the cause (refused connection, bad credentials, untrusted certificate).
				channel.ExportExceptionCallback = exception =>
					SelfLog.WriteLine("Elasticsearch export failed: {0}", exception.GetBaseException().Message);
				channel.ExportMaxRetriesCallback = failed =>
					SelfLog.WriteLine("Elasticsearch dropped {0} events after the last retry.", failed.Count);
				channel.ExportResponseCallback = (response, _) =>
				{
					// A failure without a status code is an exception, reported above.
					if (response.ApiCallDetails.HttpStatusCode is { } status && !response.ApiCallDetails.HasSuccessfulStatusCode)
					{
						SelfLog.WriteLine("Elasticsearch answered {0} to a bulk request.", status);
					}
				};
				channel.ServerRejectionCallback = rejected =>
				{
					foreach (var (_, item) in rejected)
					{
						SelfLog.WriteLine("Elasticsearch rejected an event ({0}): {1}", item.Status, item.Error?.Reason);
					}
				};
			};
		}

		/// <summary>Authentication and certificate pinning of the transport.</summary>
		public void ConfigureTransport(TransportConfigurationDescriptor transport)
		{
			if (ApiKey != null)
			{
				transport.Authentication(new ApiKey(ApiKey));
			}
			else if (UserName != null)
			{
				transport.Authentication(new BasicAuthentication(UserName, Password ?? ""));
			}
			if (CertificateFingerprint != null)
			{
				transport.CertificateFingerprint(CertificateFingerprint);
			}
		}
	}
}
