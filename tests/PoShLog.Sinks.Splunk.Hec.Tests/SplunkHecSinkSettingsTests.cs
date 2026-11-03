using System.Collections;
using System.IO;
using System.Management.Automation;
using System.Text.Json;
using PoShLog.Sinks.Splunk.Hec.Cmdlets;
using Serilog.Events;
using Serilog.Formatting.Display;
using Serilog.Parsing;
using Serilog.Sinks.Splunk;

namespace PoShLog.Sinks.Splunk.Hec.Tests;

/// <summary>Request target, payload choice and indexed fields (docs/decisions/0013-splunk-hec-sink-design.md).</summary>
public class SplunkHecSinkSettingsTests
{
	private static LogEvent Event(string text = "hello") =>
		new(DateTimeOffset.UnixEpoch, LogEventLevel.Information, null, new MessageTemplateParser().Parse(text), Array.Empty<LogEventProperty>());

	private static string Format(SplunkHecSinkSettings settings, LogEvent logEvent)
	{
		using var output = new StringWriter();
		settings.CreateFormatter().Format(logEvent, output);
		return output.ToString();
	}

	[Theory]
	[InlineData("https://splunk:8088", "https://splunk:8088/services/collector/event")]
	[InlineData("https://splunk:8088/", "https://splunk:8088/services/collector/event")]
	[InlineData("https://splunk:8088/services/collector", "https://splunk:8088/services/collector")]
	[InlineData("https://splunk:8088/services/collector/event/1.0", "https://splunk:8088/services/collector/event/1.0")]
	[InlineData("https://proxy/splunk", "https://proxy/splunk/services/collector/event")]
	public void EventEndpoint_KeepsAFullCollectorUrlAndOtherwiseAppendsThePath(string url, string expected)
	{
		Assert.Equal(expected, new SplunkHecSinkSettings { Url = url }.ResolveRequestUrl());
	}

	[Fact]
	public void UriPath_ReplacesTheDefaultPath()
	{
		var settings = new SplunkHecSinkSettings { Url = "https://proxy", UriPath = "/hec/v1/" };

		Assert.Equal("https://proxy/hec/v1", settings.ResolveRequestUrl());
	}

	[Fact]
	public void RawEndpoint_CarriesIndexSourceSourceTypeAndHostInTheQuery()
	{
		var settings = new SplunkHecSinkSettings
		{
			Url = "https://splunk:8088",
			Endpoint = HecEndpoint.Raw,
			Index = "main",
			Source = "backup job",
			SourceType = "my:raw",
			Host = "box1",
		};

		Assert.Equal("https://splunk:8088/services/collector/raw?index=main&source=backup%20job&sourcetype=my%3Araw&host=box1", settings.ResolveRequestUrl());
	}

	[Fact]
	public void RawEndpoint_AddsToAQueryTheUrlAlreadyHas()
	{
		var settings = new SplunkHecSinkSettings { Url = "https://splunk:8088/services/collector/raw?channel=abc", Endpoint = HecEndpoint.Raw, Index = "main" };

		Assert.Equal("https://splunk:8088/services/collector/raw?channel=abc&index=main", settings.ResolveRequestUrl());
	}

	[Theory]
	[InlineData("splunk:8088")]
	[InlineData("ftp://splunk")]
	[InlineData("/services/collector")]
	public void ResolveTarget_RejectsAUrlThatIsNotAbsoluteHttp(string url)
	{
		Assert.Throws<ArgumentException>(() => new SplunkHecSinkSettings { Url = url }.ResolveTarget());
	}

	[Fact]
	public void EventFormatter_WritesTheSplunkEnvelope()
	{
		var settings = new SplunkHecSinkSettings { Url = "https://splunk", Index = "main", Source = "src", SourceType = "st", Host = "box1" };

		using var json = JsonDocument.Parse(Format(settings, Event()));
		var root = json.RootElement;

		Assert.Equal("main", root.GetProperty("index").GetString());
		Assert.Equal("src", root.GetProperty("source").GetString());
		Assert.Equal("st", root.GetProperty("sourcetype").GetString());
		Assert.Equal("box1", root.GetProperty("host").GetString());
		Assert.Equal("Information", root.GetProperty("event").GetProperty("Level").GetString());
		Assert.Equal("hello", root.GetProperty("event").GetProperty("MessageTemplate").GetString());
	}

	[Fact]
	public void EventFormatter_LeavesOutWhatTheSwitchesTurnOff()
	{
		var settings = new SplunkHecSinkSettings { Url = "https://splunk", RenderTemplate = false, RenderMessage = false };

		using var json = JsonDocument.Parse(Format(settings, Event()));
		var data = json.RootElement.GetProperty("event");

		Assert.False(data.TryGetProperty("MessageTemplate", out _));
		Assert.False(data.TryGetProperty("RenderedMessage", out _));
	}

	[Fact]
	public void Fields_BecomeIndexedFields_WithListsAsMultipleValues()
	{
		var settings = new SplunkHecSinkSettings
		{
			Url = "https://splunk",
			Fields = new Hashtable { [PSObject.AsPSObject("team")] = PSObject.AsPSObject("ops"), ["tags"] = new object[] { "a", 2 } },
		};

		using var json = JsonDocument.Parse(Format(settings, Event()));
		var fields = json.RootElement.GetProperty("fields");

		Assert.Equal("ops", fields.GetProperty("team").GetString());
		Assert.Equal(new[] { "a", "2" }, fields.GetProperty("tags").EnumerateArray().Select(v => v.GetString()));
	}

	[Fact]
	public void EmptyFields_AreLeftOut()
	{
		// Serilog.Sinks.Splunk writes an unterminated "fields" object for an empty list.
		var settings = new SplunkHecSinkSettings { Url = "https://splunk", Fields = new Hashtable() };

		Assert.Null(settings.CreateCustomFields());
		using var json = JsonDocument.Parse(Format(settings, Event()));
		Assert.False(json.RootElement.TryGetProperty("fields", out _));
	}

	[Fact]
	public void RawFormatter_RendersTheOutputTemplate()
	{
		var settings = new SplunkHecSinkSettings { Url = "https://splunk", Endpoint = HecEndpoint.Raw, OutputTemplate = "[{Level:u3}] {Message:lj}" };

		Assert.IsType<MessageTemplateTextFormatter>(settings.CreateFormatter());
		Assert.Equal("[INF] hello", Format(settings, Event()));
	}

	[Fact]
	public void RawFormatter_DefaultsToATimestampedLine()
	{
		var settings = new SplunkHecSinkSettings { Url = "https://splunk", Endpoint = HecEndpoint.Raw };

		Assert.EndsWith("[INF] hello" + Environment.NewLine, Format(settings, Event()));
	}

	[Theory]
	[InlineData(HecEndpoint.Raw, "fields")]
	[InlineData(HecEndpoint.Raw, "render")]
	[InlineData(HecEndpoint.Event, "template")]
	public void Formatter_RejectsOptionsOfTheOtherEndpoint(HecEndpoint endpoint, string option)
	{
		var settings = new SplunkHecSinkSettings { Url = "https://splunk", Endpoint = endpoint };
		switch (option)
		{
			case "fields": settings.Fields = new Hashtable { ["team"] = "ops" }; break;
			case "render": settings.RenderMessage = false; break;
			case "template": settings.OutputTemplate = "{Message}"; break;
		}

		Assert.Throws<ArgumentException>(() => settings.CreateFormatter());
	}

	[Theory]
	[InlineData(5, 5.0)]
	[InlineData(0.25, 0.25)]
	[InlineData("2", 2.0)]
	[InlineData("1.5", 1.5)]
	public void BatchInterval_ReadsNumbersAsSeconds(object input, double seconds)
	{
		var transformed = new SecondsToTimeSpanAttribute().Transform(null!, PSObject.AsPSObject(input));

		Assert.Equal(TimeSpan.FromSeconds(seconds), transformed);
	}

	[Fact]
	public void BatchInterval_LeavesATimeSpanTextToPowerShell()
	{
		Assert.Equal("00:00:05", new SecondsToTimeSpanAttribute().Transform(null!, "00:00:05"));
	}
}
