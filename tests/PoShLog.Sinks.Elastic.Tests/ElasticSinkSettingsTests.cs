using System.Threading.Channels;
using Elastic.CommonSchema.Serilog;
using Elastic.Ingest.Elasticsearch;
using Elastic.Ingest.Elasticsearch.DataStreams;
using Elastic.Serilog.Sinks;
using Elastic.Transport;
using PoShLog.Sinks.Elastic.Cmdlets;

namespace PoShLog.Sinks.Elastic.Tests;

public sealed class ElasticSinkSettingsTests
{
	private static ElasticSinkSettings Settings() => new() { Nodes = [new Uri("https://es.example.com:9200")], ApiKey = "key" };

	[Theory]
	[InlineData("logs-poshlog-default", "logs", "poshlog", "default")]
	[InlineData("logs-nightly_backup-prod.eu", "logs", "nightly_backup", "prod.eu")]
	[InlineData("metrics-poshlog-default", "metrics", "poshlog", "default")]
	public void ParseDataStream_SplitsTheThreeParts(string value, string type, string dataSet, string @namespace)
	{
		var name = ElasticSinkSettings.ParseDataStream(value);

		Assert.Equal((type, dataSet, @namespace), (name.Type, name.DataSet, name.Namespace));
	}

	[Theory]
	[InlineData("")]
	[InlineData("logs")]
	[InlineData("logs-poshlog")]
	[InlineData("logs-posh-log-default")]
	[InlineData("Logs-poshlog-default")]
	[InlineData("logs-posh log-default")]
	[InlineData("logs-_poshlog-default")]
	[InlineData("logs-poshlog-*")]
	public void ParseDataStream_RejectsAnInvalidName(string value)
	{
		Assert.Throws<ArgumentException>(() => ElasticSinkSettings.ParseDataStream(value));
	}

	[Fact]
	public void Validate_AcceptsANodeWithAnApiKey()
	{
		Settings().Validate();
	}

	[Fact]
	public void Validate_AcceptsANodeWithoutCredentials()
	{
		// A cluster without security, or a proxy that authenticates.
		new ElasticSinkSettings { Nodes = [new Uri("http://localhost:9200")] }.Validate();
	}

	[Fact]
	public void Validate_RequiresNodesOrCloudId()
	{
		Assert.Throws<ArgumentException>(() => new ElasticSinkSettings { ApiKey = "key" }.Validate());
	}

	[Fact]
	public void Validate_RejectsNodesAndCloudIdTogether()
	{
		var settings = Settings();
		settings.CloudId = "poshlog:ZXhhbXBsZS5jb20kYWJjJGRlZg==";

		Assert.Throws<ArgumentException>(() => settings.Validate());
	}

	[Theory]
	[InlineData("6D:3A:2B:1C:0F:9E:8D:7C:6B:5A:49:38:27:16:05:F4:E3:D2:C1:B0:AF:9E:8D:7C:6B:5A:49:38:27:16:05:F4")]
	[InlineData("6d3a2b1c0f9e8d7c6b5a4938271605f4e3d2c1b0af9e8d7c6b5a4938271605f4")]
	public void Validate_AcceptsASha256Fingerprint(string fingerprint)
	{
		var settings = Settings();
		settings.CertificateFingerprint = fingerprint;

		settings.Validate();
	}

	[Theory]
	[InlineData("6d3a2b1c0f9e8d7c6b5a4938271605f4e3d2c1b0af9e8d7c6b5a49382716 05f4")]
	[InlineData("6d3a2b1c0f9e8d7c6b5a4938271605f4e3d2c1b0")]
	public void Validate_RejectsAnythingElseAsFingerprint(string fingerprint)
	{
		var settings = Settings();
		settings.CertificateFingerprint = fingerprint;

		Assert.Throws<ArgumentException>(() => settings.Validate());
	}

	[Fact]
	public void ConfigureSink_SetsTheStreamTheEcsFieldsAndADroppingBuffer()
	{
		var settings = Settings();
		settings.DataStream = "logs-backup-prod";
		settings.IncludeUser = false;
		settings.BatchInterval = TimeSpan.FromSeconds(1.5);
		settings.BatchSizeLimit = 50;
		settings.QueueLimit = 500;
		var options = new ElasticsearchSinkOptions();

		settings.ConfigureSink(options);
		var channel = new DataStreamChannelOptions<LogEventEcsDocument>(new DistributedTransport(new TransportConfiguration(new Uri("http://localhost:9200"))));
		options.ConfigureChannel!(channel);

		Assert.Equal("logs-backup-prod", options.DataStream.ToString());
		Assert.Equal(BootstrapMethod.None, options.BootstrapMethod);
		Assert.False(options.TextFormatting.IncludeUser);
		Assert.True(options.TextFormatting.IncludeHost);
		Assert.Equal(BoundedChannelFullMode.DropWrite, channel.BufferOptions.BoundedChannelFullMode);
		Assert.Equal(TimeSpan.FromSeconds(1.5), channel.BufferOptions.OutboundBufferMaxLifetime);
		Assert.Equal(50, channel.BufferOptions.OutboundBufferMaxSize);
		Assert.Equal(500, channel.BufferOptions.InboundBufferMaxSize);
		Assert.NotNull(channel.ExportExceptionCallback);
		Assert.NotNull(channel.ServerRejectionCallback);
	}

	[Theory]
	[InlineData(2, 2.0)]
	[InlineData(0.25, 0.25)]
	[InlineData("0.5", 0.5)]
	public void SecondsToTimeSpan_ReadsNumbersAsSeconds(object input, double seconds)
	{
		Assert.Equal(TimeSpan.FromSeconds(seconds), new SecondsToTimeSpanAttribute().Transform(null!, input));
	}
}
