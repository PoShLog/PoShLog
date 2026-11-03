using System;
using System.Collections;
using System.Globalization;
using System.Management.Automation;
using System.Net.Http;
using Serilog;
using Serilog.Configuration;
using Serilog.Core;
using Serilog.Events;
using Serilog.Sinks.Splunk;

namespace PoShLog.Sinks.Splunk.Hec.Cmdlets
{
	/// <summary>
	/// <para type="synopsis">Writes log events to a Splunk HTTP Event Collector (HEC).</para>
	/// <para type="description">Sends batches of events to the HEC event endpoint as Splunk JSON (level, message template,
	/// rendered message, properties), or to the raw endpoint as text lines.</para>
	/// </summary>
	/// <example>
	/// <code>PS> New-Logger | Add-SinkSplunk -Url 'https://splunk.example.com:8088' -Token $token -Index 'main' | Start-Logger</code>
	/// </example>
	[Cmdlet(VerbsCommon.Add, "SinkSplunk")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkSplunkCommand : PSCmdlet
	{
		/// <summary>Serilog.Sinks.Splunk's batch size.</summary>
		public const int DefaultBatchSizeLimit = 100;

		/// <summary>The package's batch interval.</summary>
		public static readonly TimeSpan DefaultBatchInterval = TimeSpan.FromSeconds(2);

		/// <summary>The package's own queue limit (it passes none to Serilog's batching, which leaves the queue unbounded).</summary>
		public const int DefaultQueueLimit = 100000;

		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; } = null!;

		/// <summary>
		/// <para type="description">The HEC base URL, such as https://splunk.example.com:8088. A URL whose path already contains
		/// services/collector is used as it is.</para>
		/// </summary>
		[Parameter(Mandatory = true, Position = 0)]
		[Alias("SplunkHost", "Uri")]
		[ValidateNotNullOrEmpty]
		public string Url { get; set; } = "";

		/// <summary><para type="description">The HEC token, sent as "Authorization: Splunk &lt;token&gt;".</para></summary>
		[Parameter(Mandatory = true, Position = 1)]
		[Alias("EventCollectorToken")]
		[ValidateNotNullOrEmpty]
		public string Token { get; set; } = "";

		/// <summary><para type="description">Event (default, Splunk JSON) or Raw (text lines).</para></summary>
		[Parameter]
		public HecEndpoint Endpoint { get; set; } = HecEndpoint.Event;

		/// <summary>
		/// <para type="description">A different collector path, for a proxy in front of Splunk. Defaults to services/collector/event
		/// or services/collector/raw.</para>
		/// </summary>
		[Parameter]
		public string? UriPath { get; set; }

		/// <summary><para type="description">The index to write to; the token's default index when omitted.</para></summary>
		[Parameter]
		public string? Index { get; set; }

		[Parameter]
		public string? Source { get; set; }

		[Parameter]
		public string? SourceType { get; set; }

		/// <summary><para type="description">The host field of the events; Splunk uses the sender's address when omitted.</para></summary>
		[Parameter]
		// Named HostName because PSCmdlet.Host is the PowerShell host; -Host is the alias.
		[Alias("Host")]
		public string? HostName { get; set; }

		/// <summary><para type="description">Indexed fields added to every event (event endpoint only). A list value becomes a multi-value field.</para></summary>
		[Parameter]
		public IDictionary? Fields { get; set; }

		/// <summary><para type="description">The text of each line on the raw endpoint.</para></summary>
		[Parameter]
		public string? OutputTemplate { get; set; }

		[Parameter]
		public IFormatProvider? FormatProvider { get; set; }

		/// <summary><para type="description">Leaves MessageTemplate out of the event JSON.</para></summary>
		[Parameter]
		public SwitchParameter DontRenderTemplate { get; set; }

		/// <summary><para type="description">Leaves RenderedMessage out of the event JSON.</para></summary>
		[Parameter]
		public SwitchParameter DontRenderMessage { get; set; }

		[Parameter]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		[Parameter]
		public LoggingLevelSwitch? LevelSwitch { get; set; }

		/// <summary><para type="description">How long events are buffered before a request (default 2 seconds). A number means seconds.</para></summary>
		[Parameter]
		[Alias("BatchIntervalSeconds")]
		[SecondsToTimeSpan]
		public TimeSpan? BatchInterval { get; set; }

		/// <summary><para type="description">Maximum events per request (default 100).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? BatchSizeLimit { get; set; }

		/// <summary><para type="description">Maximum events waiting to be sent; later ones are dropped (default 100000).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? QueueLimit { get; set; }

		/// <summary><para type="description">Handler for the HTTP client, for proxies or client certificates.</para></summary>
		[Parameter]
		public HttpMessageHandler? HttpMessageHandler { get; set; }

		/// <inheritdoc />
		protected override void ProcessRecord()
		{
			var settings = new SplunkHecSinkSettings
			{
				Url = Url,
				Endpoint = Endpoint,
				UriPath = UriPath,
				Index = Index,
				Source = Source,
				SourceType = SourceType,
				Host = HostName,
				Fields = Fields,
				OutputTemplate = OutputTemplate,
				FormatProvider = FormatProvider,
				RenderTemplate = !DontRenderTemplate.IsPresent,
				RenderMessage = !DontRenderMessage.IsPresent,
			};
			var interval = BatchInterval ?? DefaultBatchInterval;

			EventCollectorSink sink;
			try
			{
				if (interval <= TimeSpan.Zero)
				{
					throw new ArgumentException($"BatchInterval must be positive, not {interval}.");
				}
				var (host, path) = settings.ResolveTarget();
				sink = new EventCollectorSink(host, Token, path, settings.CreateFormatter(), HttpMessageHandler);
			}
			catch (ArgumentException exception)
			{
				ThrowTerminatingError(new ErrorRecord(exception, "InvalidSplunkSinkArgument", ErrorCategory.InvalidArgument, Url));
				return;
			}

			// Built here rather than through WriteTo.EventCollector, which takes whole seconds and no formatter with source,
			// index or host.
			var batching = new BatchingOptions
			{
				BatchSizeLimit = BatchSizeLimit ?? DefaultBatchSizeLimit,
				BufferingTimeLimit = interval,
				EagerlyEmitFirstEvent = true,
				QueueLimit = QueueLimit ?? DefaultQueueLimit,
			};
			LoggerConfig.WriteTo.Sink(sink, batching, RestrictedToMinimumLevel, LevelSwitch);

			WriteObject(LoggerConfig);
		}
	}

	/// <summary>Reads a bare number as seconds, as the third-party module's -BatchIntervalSeconds did.</summary>
	public sealed class SecondsToTimeSpanAttribute : ArgumentTransformationAttribute
	{
		public override object? Transform(EngineIntrinsics engineIntrinsics, object? inputData)
		{
			var value = inputData is PSObject psObject ? psObject.BaseObject : inputData;
			return value switch
			{
				int seconds => TimeSpan.FromSeconds(seconds),
				long seconds => TimeSpan.FromSeconds(seconds),
				double seconds => TimeSpan.FromSeconds(seconds),
				decimal seconds => TimeSpan.FromSeconds((double)seconds),
				// "5" would otherwise parse as five days.
				string text when double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var seconds) => TimeSpan.FromSeconds(seconds),
				_ => inputData,
			};
		}
	}
}
