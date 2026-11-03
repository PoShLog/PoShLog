using System;
using System.Globalization;
using System.Management.Automation;
using Elastic.Ingest.Elasticsearch;
using Elastic.Serilog.Sinks;
using Serilog;
using Serilog.Core;
using Serilog.Events;

namespace PoShLog.Sinks.Elastic.Cmdlets
{
	/// <summary>
	/// <para type="synopsis">Writes log events to Elasticsearch or Elastic Cloud.</para>
	/// <para type="description">Sends batches of events to a data stream (logs-poshlog-default by default) through the bulk
	/// API, as Elastic Common Schema (ECS) documents.</para>
	/// </summary>
	/// <example>
	/// <code>PS> New-Logger | Add-SinkElasticsearch -Node 'https://es.example.com:9200' -ApiKey $env:ES_API_KEY | Start-Logger</code>
	/// </example>
	[Cmdlet(VerbsCommon.Add, "SinkElasticsearch", DefaultParameterSetName = NodeSet)]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkElasticsearchCommand : PSCmdlet
	{
		private const string NodeSet = "Node";
		private const string CloudSet = "Cloud";

		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; } = null!;

		/// <summary><para type="description">One or more Elasticsearch node URLs, such as https://es.example.com:9200.</para></summary>
		[Parameter(Mandatory = true, Position = 0, ParameterSetName = NodeSet)]
		[Alias("Uri", "Nodes")]
		[ValidateNotNullOrEmpty]
		public Uri[] Node { get; set; } = [];

		/// <summary><para type="description">The Cloud ID of an Elastic Cloud deployment.</para></summary>
		[Parameter(Mandatory = true, ParameterSetName = CloudSet)]
		[ValidateNotNullOrEmpty]
		public string CloudId { get; set; } = "";

		/// <summary><para type="description">An API key (the encoded form), sent as "Authorization: ApiKey &lt;key&gt;".</para></summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string? ApiKey { get; set; }

		/// <summary><para type="description">A user name and password for basic authentication.</para></summary>
		[Parameter]
		[Credential]
		public PSCredential? Credential { get; set; }

		/// <summary><para type="description">The data stream as type-dataset-namespace (default logs-poshlog-default).</para></summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string DataStream { get; set; } = ElasticSinkSettings.DefaultDataStream;

		/// <summary>
		/// <para type="description">None (default) writes to an existing data stream or the cluster's built-in logs-*-*
		/// template; Silent and Failure install this sink's index template first, Failure stopping the sink when that fails.</para>
		/// </summary>
		[Parameter]
		public BootstrapMethod BootstrapMethod { get; set; } = BootstrapMethod.None;

		/// <summary><para type="description">The ILM policy the bootstrapped template refers to.</para></summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string? IlmPolicy { get; set; }

		/// <summary>
		/// <para type="description">The SHA-256 fingerprint of the cluster's CA or server certificate, such as the self-signed CA
		/// that Elasticsearch 8 generates.</para>
		/// </summary>
		[Parameter]
		[Alias("CaFingerprint")]
		[ValidateNotNullOrEmpty]
		public string? CertificateFingerprint { get; set; }

		[Parameter]
		public IFormatProvider? FormatProvider { get; set; }

		/// <summary><para type="description">Leaves the host.* fields (name, OS) out of the documents.</para></summary>
		[Parameter]
		public SwitchParameter ExcludeHost { get; set; }

		/// <summary><para type="description">Leaves the process.* fields (name, ID, thread) out of the documents.</para></summary>
		[Parameter]
		public SwitchParameter ExcludeProcess { get; set; }

		/// <summary><para type="description">Leaves the user.* fields (name, domain) out of the documents.</para></summary>
		[Parameter]
		public SwitchParameter ExcludeUser { get; set; }

		[Parameter]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		[Parameter]
		public LoggingLevelSwitch? LevelSwitch { get; set; }

		/// <summary><para type="description">How long events are buffered before a bulk request (default 2 seconds, at least 1). A number means seconds.</para></summary>
		[Parameter]
		[SecondsToTimeSpan]
		public TimeSpan? BatchInterval { get; set; }

		/// <summary><para type="description">Maximum events per bulk request (default 1000).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? BatchSizeLimit { get; set; }

		/// <summary><para type="description">Maximum events waiting to be sent; later ones are dropped (default 100000).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? QueueLimit { get; set; }

		/// <inheritdoc />
		protected override void ProcessRecord()
		{
			var password = Credential?.GetNetworkCredential().Password;
			var settings = new ElasticSinkSettings
			{
				Nodes = ParameterSetName == NodeSet ? Node : null,
				CloudId = ParameterSetName == CloudSet ? CloudId : null,
				ApiKey = ApiKey,
				UserName = Credential?.UserName,
				Password = password,
				DataStream = DataStream,
				BootstrapMethod = BootstrapMethod,
				IlmPolicy = IlmPolicy,
				CertificateFingerprint = CertificateFingerprint,
				FormatProvider = FormatProvider,
				IncludeHost = !ExcludeHost.IsPresent,
				IncludeProcess = !ExcludeProcess.IsPresent,
				IncludeUser = !ExcludeUser.IsPresent,
				BatchInterval = BatchInterval ?? ElasticSinkSettings.DefaultBatchInterval,
				BatchSizeLimit = BatchSizeLimit ?? ElasticSinkSettings.DefaultBatchSizeLimit,
				QueueLimit = QueueLimit ?? ElasticSinkSettings.DefaultQueueLimit,
			};
			try
			{
				settings.Validate();
			}
			catch (ArgumentException exception)
			{
				ThrowTerminatingError(new ErrorRecord(exception, "InvalidElasticsearchSinkArgument", ErrorCategory.InvalidArgument, DataStream));
				return;
			}

			if (settings.Nodes != null)
			{
				LoggerConfig.WriteTo.Elasticsearch(settings.Nodes, settings.ConfigureSink, settings.ConfigureTransport, useSniffing: false,
					LevelSwitch, RestrictedToMinimumLevel);
			}
			else if (settings.ApiKey != null)
			{
				ElasticsearchSinkExtensions.ElasticCloud(LoggerConfig.WriteTo, CloudId, settings.ApiKey, settings.ConfigureSink, settings.ConfigureTransport, LevelSwitch,
					RestrictedToMinimumLevel);
			}
			else
			{
				ElasticsearchSinkExtensions.ElasticCloud(LoggerConfig.WriteTo, CloudId, settings.UserName!, password ?? "", settings.ConfigureSink, settings.ConfigureTransport,
					LevelSwitch, RestrictedToMinimumLevel);
			}

			WriteObject(LoggerConfig);
		}
	}

	/// <summary>Reads a bare number as seconds.</summary>
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
