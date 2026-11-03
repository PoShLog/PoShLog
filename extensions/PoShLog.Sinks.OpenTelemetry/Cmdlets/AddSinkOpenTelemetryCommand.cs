using System;
using System.Collections;
using System.Management.Automation;
using System.Net.Http;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Serilog.Sinks.OpenTelemetry;

namespace PoShLog.Sinks.OpenTelemetry.Cmdlets
{
	/// <summary>
	/// <para type="synopsis">Writes log events to an OpenTelemetry (OTLP) endpoint.</para>
	/// <para type="description">Sends events as OTLP log records over HTTP/protobuf or gRPC to an OpenTelemetry Collector or any
	/// backend with an OTLP intake (Seq, Grafana Alloy, .NET Aspire, Datadog Agent, Splunk, Elastic).</para>
	/// </summary>
	/// <example>
	/// <code>PS> New-Logger | Add-SinkOpenTelemetry -Endpoint 'http://localhost:4318' -ServiceName 'backup' | Start-Logger</code>
	/// </example>
	[Cmdlet(VerbsCommon.Add, "SinkOpenTelemetry")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkOpenTelemetryCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; } = null!;

		/// <summary>
		/// <para type="description">Base URL of the OTLP receiver. With HttpProtobuf, /v1/logs is appended to its path. Defaults to
		/// http://localhost:4318 (HttpProtobuf) or http://localhost:4317 (Grpc).</para>
		/// </summary>
		[Parameter(Position = 0)]
		public string? Endpoint { get; set; }

		/// <summary><para type="description">HttpProtobuf (default) or Grpc.</para></summary>
		[Parameter]
		public OtlpProtocol Protocol { get; set; } = OtlpProtocol.HttpProtobuf;

		/// <summary><para type="description">HTTP headers or gRPC metadata sent with every export, such as an API key.</para></summary>
		[Parameter]
		public IDictionary? Headers { get; set; }

		/// <summary><para type="description">Resource attributes describing the source, such as deployment.environment.</para></summary>
		[Parameter]
		public IDictionary? ResourceAttributes { get; set; }

		/// <summary><para type="description">Sets the service.name resource attribute.</para></summary>
		[Parameter]
		public string? ServiceName { get; set; }

		/// <summary><para type="description">Which optional fields and attributes each log record carries.</para></summary>
		[Parameter]
		public IncludedData? IncludedData { get; set; }

		[Parameter]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		[Parameter]
		public LoggingLevelSwitch? LevelSwitch { get; set; }

		/// <summary><para type="description">Maximum events per export request (default 1000).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? BatchSizeLimit { get; set; }

		/// <summary><para type="description">How long events are buffered before an export (default 2 seconds).</para></summary>
		[Parameter]
		public TimeSpan? Period { get; set; }

		/// <summary><para type="description">Maximum events waiting to be exported; later ones are dropped (default 100000).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? QueueLimit { get; set; }

		/// <summary><para type="description">Handler for the exporter's HTTP client, for proxies or client certificates.</para></summary>
		[Parameter]
		public HttpMessageHandler? HttpMessageHandler { get; set; }

		/// <summary><para type="description">Ignores the OTEL_* environment variables.</para></summary>
		[Parameter]
		public SwitchParameter IgnoreEnvironment { get; set; }

		/// <inheritdoc />
		protected override void ProcessRecord()
		{
			var settings = new OpenTelemetrySinkSettings
			{
				Endpoint = Endpoint,
				Protocol = MyInvocation.BoundParameters.ContainsKey(nameof(Protocol)) ? Protocol : null,
				Headers = Headers,
				ResourceAttributes = ResourceAttributes,
				ServiceName = ServiceName,
				IgnoreEnvironment = IgnoreEnvironment.IsPresent,
			};

			LoggerConfig.WriteTo.OpenTelemetry(options =>
			{
				settings.Apply(options);
				if (IncludedData is { } includedData)
				{
					options.IncludedData = includedData;
				}
				options.RestrictedToMinimumLevel = RestrictedToMinimumLevel;
				options.LevelSwitch = LevelSwitch;
				options.HttpMessageHandler = HttpMessageHandler;
				if (BatchSizeLimit is { } batchSizeLimit)
				{
					options.BatchingOptions.BatchSizeLimit = batchSizeLimit;
				}
				if (Period is { } period)
				{
					options.BatchingOptions.BufferingTimeLimit = period;
				}
				if (QueueLimit is { } queueLimit)
				{
					options.BatchingOptions.QueueLimit = queueLimit;
				}
			}, settings.CreateEnvironmentReader());

			WriteObject(LoggerConfig);
		}
	}
}
