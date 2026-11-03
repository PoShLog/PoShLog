using System.Collections.Concurrent;
using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace PoShLog.Sinks.Splunk.Hec.Tests;

/// <summary>One request as the HEC stand-in saw it.</summary>
public sealed record HecRequest(string Path, string Query, string ContentType, IReadOnlyDictionary<string, string> Headers, string Body);

/// <summary>
/// A local stand-in for the Splunk HTTP Event Collector on a loopback ephemeral port. Like Splunk, it answers a request
/// whose token is not "Splunk &lt;token&gt;" with 403 and every other request with {"text":"Success","code":0}.
/// </summary>
public sealed class HecReceiver : IAsyncDisposable
{
	private readonly WebApplication _app;
	private readonly string _token;

	public BlockingCollection<HecRequest> Requests { get; } = new();
	public string Url { get; private set; } = "";

	private HecReceiver(WebApplication app, string token)
	{
		_app = app;
		_token = token;
	}

	public static async Task<HecReceiver> StartAsync(string token)
	{
		var builder = WebApplication.CreateSlimBuilder();
		builder.Logging.ClearProviders();
		builder.WebHost.ConfigureKestrel(kestrel => kestrel.Listen(IPAddress.Loopback, 0));
		var app = builder.Build();
		var receiver = new HecReceiver(app, token);
		app.Run(receiver.HandleAsync);
		await app.StartAsync();
		receiver.Url = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.Single();
		return receiver;
	}

	/// <summary>Waits for a request whose body contains <paramref name="marker"/>.</summary>
	public HecRequest WaitFor(string marker, TimeSpan timeout)
	{
		var deadline = DateTime.UtcNow + timeout;
		while (DateTime.UtcNow < deadline)
		{
			if (Requests.TryTake(out var request, TimeSpan.FromMilliseconds(100)) && request.Body.Contains(marker))
			{
				return request;
			}
		}
		throw new TimeoutException($"No HEC request containing '{marker}' arrived within {timeout}.");
	}

	private async Task HandleAsync(HttpContext context)
	{
		using var reader = new StreamReader(context.Request.Body);
		var body = await reader.ReadToEndAsync();
		var headers = context.Request.Headers.ToDictionary(h => h.Key.ToLowerInvariant(), h => h.Value.ToString());
		Requests.Add(new HecRequest(context.Request.Path, context.Request.QueryString.Value ?? "", context.Request.ContentType ?? "", headers, body));

		context.Response.ContentType = "application/json";
		if (context.Request.Headers.Authorization.ToString() != $"Splunk {_token}")
		{
			context.Response.StatusCode = StatusCodes.Status403Forbidden;
			await context.Response.WriteAsync("{\"text\":\"Invalid token\",\"code\":4}");
			return;
		}
		await context.Response.WriteAsync("{\"text\":\"Success\",\"code\":0}");
	}

	public async ValueTask DisposeAsync()
	{
		await _app.StopAsync();
		await _app.DisposeAsync();
		Requests.Dispose();
	}
}
