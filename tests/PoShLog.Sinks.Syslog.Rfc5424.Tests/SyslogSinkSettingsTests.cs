using System.Globalization;
using System.Net.Security;
using System.Text;
using PoShLog.Sinks.Syslog.Rfc5424.Cmdlets;
using Serilog.Events;
using Serilog.Parsing;
using Serilog.Sinks.Syslog;

namespace PoShLog.Sinks.Syslog.Rfc5424.Tests;

public sealed class SyslogSinkSettingsTests
{
	private static LogEvent Event(string template, LogEventLevel level = LogEventLevel.Information, Exception? exception = null,
		params (string Name, object Value)[] properties) =>
		new(new DateTimeOffset(2026, 11, 3, 10, 15, 30, TimeSpan.Zero), level, exception, new MessageTemplateParser().Parse(template),
			properties.Select(p => new LogEventProperty(p.Name, new ScalarValue(p.Value))));

	private static SyslogSinkSettings Settings(SyslogMessageFormat format = SyslogMessageFormat.Rfc5424) =>
		new() { Hostname = "syslog.example.com", Format = format, AppName = "backup", SourceHost = "web01" };

	[Theory]
	[InlineData(SyslogProtocol.Udp, 514)]
	[InlineData(SyslogProtocol.Tcp, 514)]
	[InlineData(SyslogProtocol.TcpTls, 6514)]
	public void ResolvePort_DefaultsByProtocol(SyslogProtocol protocol, int expected)
	{
		Assert.Equal(expected, new SyslogSinkSettings { Protocol = protocol }.ResolvePort());
	}

	[Fact]
	public void ResolvePort_KeepsAnExplicitPort()
	{
		Assert.Equal(1468, new SyslogSinkSettings { Protocol = SyslogProtocol.TcpTls, Port = 1468 }.ResolvePort());
	}

	[Theory]
	[InlineData(0)]
	[InlineData(65536)]
	public void ResolvePort_RejectsAPortOutOfRange(int port)
	{
		Assert.Throws<ArgumentException>(() => new SyslogSinkSettings { Port = port }.ResolvePort());
	}

	[Fact]
	public void CreateFormatter_RequiresAHostname()
	{
		Assert.Throws<ArgumentException>(() => new SyslogSinkSettings { Hostname = " " }.CreateFormatter());
	}

	[Fact]
	public void Rfc5424_CarriesHeaderFieldsAndPropertiesAsStructuredData()
	{
		var message = Settings().CreateFormatter().FormatMessage(
			Event("Backed up {Count} databases", LogEventLevel.Warning, null, ("Count", 12), ("SourceContext", "Nightly")));

		// Local0 (16) * 8 + Warning (4) = 132.
		Assert.StartsWith("<132>1 2026-11-03T", message);
		Assert.Contains(" web01 backup ", message);
		Assert.Contains(" Nightly [poshlog@32473 Count=\"12\" SourceContext=\"Nightly\"] Backed up 12 databases", message);
		Assert.EndsWith("Backed up 12 databases", message);
	}

	[Fact]
	public void Rfc5424_UsesACustomStructuredDataId()
	{
		var settings = Settings();
		settings.StructuredDataId = "backup@32473";

		Assert.Contains("[backup@32473 Count=\"1\"]", settings.CreateFormatter().FormatMessage(Event("{Count}", properties: ("Count", 1))));
	}

	[Theory]
	[InlineData("")]
	[InlineData("a b")]
	[InlineData("a=b")]
	[InlineData("a]")]
	[InlineData("a\"")]
	public void Rfc5424_RejectsAnInvalidStructuredDataId(string id)
	{
		var settings = Settings();
		settings.StructuredDataId = id;

		Assert.Throws<ArgumentException>(() => settings.CreateFormatter());
	}

	[Fact]
	public void Rfc3164_HasTheBsdShape()
	{
		var message = Settings(SyslogMessageFormat.Rfc3164).CreateFormatter().FormatMessage(Event("Started", LogEventLevel.Error));

		// Local0 (16) * 8 + Error (3) = 131.
		Assert.Matches(@"^<131>[A-Z][a-z]{2} [ \d]\d \d\d:\d\d:\d\d web01 backup\[\d+\]: Started$", message);
	}

	[Fact]
	public void Facility_SetsThePriority()
	{
		var settings = Settings();
		settings.Facility = Facility.User;

		// User (1) * 8 + Informational (6) = 14.
		Assert.StartsWith("<14>1 ", settings.CreateFormatter().FormatMessage(Event("x")));
	}

	[Theory]
	[InlineData(LogEventLevel.Verbose, "<135>1 ")]
	[InlineData(LogEventLevel.Debug, "<135>1 ")]
	[InlineData(LogEventLevel.Information, "<134>1 ")]
	[InlineData(LogEventLevel.Warning, "<132>1 ")]
	[InlineData(LogEventLevel.Error, "<131>1 ")]
	[InlineData(LogEventLevel.Fatal, "<130>1 ")]
	public void Level_MapsToASeverityInOrder(LogEventLevel level, string expected)
	{
		// Local0 (16) * 8 + Debug (7), Informational (6), Warning (4), Error (3), Critical (2); never Notice or Emergency.
		Assert.StartsWith(expected, Settings().CreateFormatter().FormatMessage(Event("x", level)));
	}

	[Fact]
	public void Message_RendersStringsWithoutQuotesAndKeepsTheException()
	{
		var message = Settings().CreateFormatter().FormatMessage(
			Event("Hello {Name}", LogEventLevel.Error, new InvalidOperationException("boom"), ("Name", "Tomas")));

		Assert.Contains("Hello Tomas" + Environment.NewLine + "System.InvalidOperationException: boom", message);
	}

	[Fact]
	public void Message_DropsTheTrailingLineBreakOfAnEventWithoutException()
	{
		var message = Settings(SyslogMessageFormat.Rfc3164).CreateFormatter().FormatMessage(Event("Done"));

		Assert.EndsWith(": Done", message);
	}

	[Fact]
	public void OutputTemplate_FormatsTheMessage()
	{
		var settings = Settings(SyslogMessageFormat.Rfc3164);
		settings.OutputTemplate = "[{Level:u3}] {Message:lj} ({Count})";
		settings.FormatProvider = CultureInfo.InvariantCulture;

		Assert.EndsWith(": [INF] Copied 1.5 (1.5)", settings.CreateFormatter().FormatMessage(Event("Copied {Count}", properties: ("Count", 1.5))));
	}

	[Theory]
	[InlineData(SyslogFraming.OctetCounting, "6 h\u00e9llo")]
	[InlineData(SyslogFraming.Lf, "h\u00e9llo\n")]
	[InlineData(SyslogFraming.CrLf, "h\u00e9llo\r\n")]
	[InlineData(SyslogFraming.Cr, "h\u00e9llo\r")]
	[InlineData(SyslogFraming.Nul, "h\u00e9llo\0")]
	public async Task CreateFramer_DelimitsMessages(SyslogFraming framing, string expected)
	{
		using var stream = new MemoryStream();

		await new SyslogSinkSettings { Framing = framing }.CreateFramer().WriteFrame("h\u00e9llo", stream);

		// Octet counting counts bytes: é is two.
		Assert.Equal(expected, Encoding.UTF8.GetString(stream.ToArray()));
	}

	[Fact]
	public void Truncate_KeepsAShortDatagram()
	{
		var payload = Encoding.UTF8.GetBytes("short");

		Assert.Equal(payload, SyslogUdpTransport.Truncate(payload).ToArray());
	}

	[Fact]
	public void Truncate_CutsALongDatagramAtACharacterBoundary()
	{
		var payload = Encoding.UTF8.GetBytes(new string('a', SyslogUdpTransport.MaxDatagramBytes - 1) + "\u00e9\u00e9");

		var cut = SyslogUdpTransport.Truncate(payload);

		Assert.Equal(SyslogUdpTransport.MaxDatagramBytes - 1, cut.Length);
		Assert.Equal(new string('a', SyslogUdpTransport.MaxDatagramBytes - 1), Encoding.UTF8.GetString(cut.Span));
	}

	[Theory]
	[InlineData("abc")]
	[InlineData("zz00000000000000000000000000000000000000")]
	public void PinnedCertificates_RejectsAMalformedThumbprint(string thumbprint)
	{
		Assert.Throws<ArgumentException>(() => SyslogSinkSettings.PinnedCertificates([thumbprint]));
	}

	[Fact]
	public void PinnedCertificates_KeepsTheSystemDecisionForATrustedCertificate()
	{
		var callback = SyslogSinkSettings.PinnedCertificates(["AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD"]);

		Assert.True(callback(this, null, null, SslPolicyErrors.None));
		Assert.False(callback(this, null, null, SslPolicyErrors.RemoteCertificateChainErrors));
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
