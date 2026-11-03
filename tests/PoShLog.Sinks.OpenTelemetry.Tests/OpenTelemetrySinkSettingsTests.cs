using System.Collections;
using System.Management.Automation;
using Serilog.Sinks.OpenTelemetry;

namespace PoShLog.Sinks.OpenTelemetry.Tests;

/// <summary>Parameter mapping and the OTEL_* environment rules (docs/decisions/0012-otlp-sink-design.md).</summary>
public class OpenTelemetrySinkSettingsTests
{
	private static OpenTelemetrySinkSettings With(Dictionary<string, string> environment) =>
		new() { GetEnvironmentVariable = name => environment.TryGetValue(name, out var value) ? value : null };

	private static OpenTelemetrySinkSettings WithoutEnvironment() => With(new());

	[Fact]
	public void Defaults_AreOtlpHttpOnPort4318()
	{
		var settings = WithoutEnvironment();

		Assert.Equal(OtlpProtocol.HttpProtobuf, settings.ResolveProtocol());
		Assert.Equal("http://localhost:4318", settings.ResolveEndpoint());
	}

	[Fact]
	public void Grpc_DefaultsToPort4317()
	{
		var settings = WithoutEnvironment();
		settings.Protocol = OtlpProtocol.Grpc;

		Assert.Equal("http://localhost:4317", settings.ResolveEndpoint());
	}

	[Theory]
	[InlineData("grpc", OtlpProtocol.Grpc)]
	[InlineData(" GRPC ", OtlpProtocol.Grpc)]
	[InlineData("http/protobuf", OtlpProtocol.HttpProtobuf)]
	[InlineData("http/json", OtlpProtocol.HttpProtobuf)]
	public void ProtocolVariable_ChoosesTheProtocolWhenNoParameterIsGiven(string value, OtlpProtocol expected)
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.ProtocolVariable] = value });

		Assert.Equal(expected, settings.ResolveProtocol());
	}

	[Fact]
	public void ProtocolParameter_WinsOverTheVariable()
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.ProtocolVariable] = "grpc" });
		settings.Protocol = OtlpProtocol.HttpProtobuf;

		Assert.Equal(OtlpProtocol.HttpProtobuf, settings.ResolveProtocol());
		Assert.Null(settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.ProtocolVariable));
	}

	[Fact]
	public void EndpointVariable_IsHiddenWhenEndpointIsGiven()
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.EndpointVariable] = "http://collector:4318" });
		settings.Endpoint = "http://127.0.0.1:9999";

		Assert.Null(settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.EndpointVariable));
		Assert.Equal("http://127.0.0.1:9999", settings.ResolveEndpoint());
	}

	[Fact]
	public void EndpointVariable_IsPassedOnWhenNoEndpointIsGiven()
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.EndpointVariable] = "http://collector:4318" });

		Assert.Equal("http://collector:4318", settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.EndpointVariable));
	}

	[Fact]
	public void HeadersVariable_DropsHeadersGivenInCode_CaseInsensitive()
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.HeadersVariable] = "X-Api-Key=env, x-tenant=t1" });
		settings.Headers = new Hashtable { ["x-api-key"] = "code" };

		Assert.Equal(" x-tenant=t1", settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.HeadersVariable));
	}

	[Fact]
	public void ResourceAttributesVariable_DropsKeysGivenInCode()
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.ResourceAttributesVariable] = "service.name=env,host.name=h1,team=ops" });
		settings.ServiceName = "code";
		settings.ResourceAttributes = new Hashtable { ["team"] = "dev" };

		Assert.Equal("host.name=h1", settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.ResourceAttributesVariable));
	}

	[Fact]
	public void ResourceAttributesVariable_IsNullWhenEveryKeyIsGivenInCode()
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.ResourceAttributesVariable] = "team=ops" });
		settings.ResourceAttributes = new Hashtable { ["team"] = "dev" };

		Assert.Null(settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.ResourceAttributesVariable));
	}

	[Theory]
	[InlineData(true, false)]
	[InlineData(false, true)]
	public void ServiceNameVariable_IsHiddenWhenTheServiceNameIsSetInCode(bool asParameter, bool asAttribute)
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.ServiceNameVariable] = "env" });
		if (asParameter)
		{
			settings.ServiceName = "code";
		}
		if (asAttribute)
		{
			settings.ResourceAttributes = new Hashtable { ["service.name"] = "code" };
		}

		Assert.Null(settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.ServiceNameVariable));
	}

	[Fact]
	public void ServiceNameVariable_IsPassedOnWhenNotSetInCode()
	{
		var settings = With(new() { [OpenTelemetrySinkSettings.ServiceNameVariable] = "env" });

		Assert.Equal("env", settings.CreateEnvironmentReader()(OpenTelemetrySinkSettings.ServiceNameVariable));
	}

	[Fact]
	public void IgnoreEnvironment_HidesEveryVariable()
	{
		var settings = With(new()
		{
			[OpenTelemetrySinkSettings.EndpointVariable] = "http://collector:4318",
			[OpenTelemetrySinkSettings.ProtocolVariable] = "grpc",
			[OpenTelemetrySinkSettings.ServiceNameVariable] = "env",
		});
		settings.IgnoreEnvironment = true;
		var read = settings.CreateEnvironmentReader();

		Assert.Equal(OtlpProtocol.HttpProtobuf, settings.ResolveProtocol());
		Assert.Null(read(OpenTelemetrySinkSettings.EndpointVariable));
		Assert.Null(read(OpenTelemetrySinkSettings.ProtocolVariable));
		Assert.Null(read(OpenTelemetrySinkSettings.ServiceNameVariable));
	}

	[Fact]
	public void Apply_CopiesHeadersAndAttributes_AndUnwrapsPowerShellValues()
	{
		var settings = WithoutEnvironment();
		settings.Endpoint = "http://127.0.0.1:1234";
		settings.Protocol = OtlpProtocol.Grpc;
		settings.ServiceName = "backup";
		settings.Headers = new Hashtable { [PSObject.AsPSObject("x-api-key")] = PSObject.AsPSObject("k1") };
		settings.ResourceAttributes = new Hashtable { ["retries"] = PSObject.AsPSObject(6), ["deployment.environment"] = "test" };
		var options = new BatchedOpenTelemetrySinkOptions();

		settings.Apply(options);

		Assert.Equal("http://127.0.0.1:1234", options.Endpoint);
		Assert.Equal(OtlpProtocol.Grpc, options.Protocol);
		Assert.Equal("k1", options.Headers["x-api-key"]);
		Assert.Equal(6, Assert.IsType<int>(options.ResourceAttributes["retries"]));
		Assert.Equal("test", options.ResourceAttributes["deployment.environment"]);
		Assert.Equal("backup", options.ResourceAttributes["service.name"]);
	}

	[Fact]
	public void ServiceNameParameter_WinsOverTheServiceNameAttribute()
	{
		var settings = WithoutEnvironment();
		settings.ServiceName = "parameter";
		settings.ResourceAttributes = new Hashtable { ["service.name"] = "attribute" };
		var options = new BatchedOpenTelemetrySinkOptions();

		settings.Apply(options);

		Assert.Equal("parameter", options.ResourceAttributes["service.name"]);
	}
}
