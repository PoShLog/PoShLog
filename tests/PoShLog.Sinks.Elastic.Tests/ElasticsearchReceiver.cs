using System.Collections.Concurrent;
using System.IO.Compression;
using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace PoShLog.Sinks.Elastic.Tests;

/// <summary>One request as the Elasticsearch stand-in saw it, its body decompressed.</summary>
public sealed record ElasticsearchRequest(string Method, string Path, string Query, IReadOnlyDictionary<string, string> Headers, string Body);

/// <summary>
/// A local stand-in for Elasticsearch on a loopback ephemeral port. Like Elasticsearch, it sends the product header the
/// client checks, answers a request without the expected Authorization header with 401, a bulk request with one item per
/// event, and template requests with {"acknowledged":true}. <see cref="RejectDocuments"/> makes it reject every document.
/// </summary>
public sealed class ElasticsearchReceiver : IAsyncDisposable
{
	private readonly WebApplication _app;
	private readonly string _authorization;

	public BlockingCollection<ElasticsearchRequest> Requests { get; } = new();

	/// <summary>All requests so far, in order.</summary>
	public ConcurrentQueue<ElasticsearchRequest> Log { get; } = new();

	public string Url { get; private set; } = "";

	public bool RejectDocuments { get; set; }

	/// <summary>Templates created with PUT; HEAD finds only these, as on an empty cluster.</summary>
	private readonly ConcurrentDictionary<string, bool> _created = new();

	private ElasticsearchReceiver(WebApplication app, string authorization)
	{
		_app = app;
		_authorization = authorization;
	}

	public static async Task<ElasticsearchReceiver> StartAsync(string authorization)
	{
		var builder = WebApplication.CreateSlimBuilder();
		builder.Logging.ClearProviders();
		builder.WebHost.ConfigureKestrel(kestrel => kestrel.Listen(IPAddress.Loopback, 0));
		var app = builder.Build();
		var receiver = new ElasticsearchReceiver(app, authorization);
		app.Run(receiver.HandleAsync);
		await app.StartAsync();
		receiver.Url = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.Single();
		return receiver;
	}

	/// <summary>Waits for a bulk request whose body contains <paramref name="marker"/>.</summary>
	public ElasticsearchRequest WaitForBulk(string marker, TimeSpan timeout)
	{
		var deadline = DateTime.UtcNow + timeout;
		while (DateTime.UtcNow < deadline)
		{
			if (Requests.TryTake(out var request, TimeSpan.FromMilliseconds(100)) && request.Path.EndsWith("/_bulk") && request.Body.Contains(marker))
			{
				return request;
			}
		}
		throw new TimeoutException($"No bulk request containing '{marker}' arrived within {timeout}.");
	}

	private async Task HandleAsync(HttpContext context)
	{
		var input = context.Request.Headers.ContentEncoding.ToString() == "gzip"
			? new GZipStream(context.Request.Body, CompressionMode.Decompress)
			: context.Request.Body;
		using var reader = new StreamReader(input);
		var body = await reader.ReadToEndAsync();
		var headers = context.Request.Headers.ToDictionary(h => h.Key.ToLowerInvariant(), h => h.Value.ToString());
		var request = new ElasticsearchRequest(context.Request.Method, context.Request.Path, context.Request.QueryString.Value ?? "", headers, body);
		Log.Enqueue(request);
		Requests.Add(request);

		context.Response.Headers["X-Elastic-Product"] = "Elasticsearch";
		context.Response.ContentType = "application/json";
		if (context.Request.Headers.Authorization.ToString() != _authorization)
		{
			context.Response.StatusCode = StatusCodes.Status401Unauthorized;
			await context.Response.WriteAsync("{\"error\":{\"type\":\"security_exception\",\"reason\":\"unable to authenticate\"},\"status\":401}");
			return;
		}
		if (HttpMethods.IsHead(context.Request.Method))
		{
			if (context.Request.Path != "/" && !_created.ContainsKey(context.Request.Path!))
			{
				context.Response.StatusCode = StatusCodes.Status404NotFound;
			}
			return;
		}
		if (HttpMethods.IsPut(context.Request.Method))
		{
			_created[context.Request.Path!] = true;
		}
		if (context.Request.Path.Value!.EndsWith("/_bulk"))
		{
			var count = body.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length / 2;
			var item = RejectDocuments
				? "{\"create\":{\"status\":400,\"error\":{\"type\":\"document_parsing_exception\",\"reason\":\"stand-in rejects documents\"}}}"
				: "{\"create\":{\"status\":201,\"result\":\"created\"}}";
			await context.Response.WriteAsync(
				$"{{\"took\":1,\"errors\":{(RejectDocuments ? "true" : "false")},\"items\":[{string.Join(",", Enumerable.Repeat(item, count))}]}}");
			return;
		}
		await context.Response.WriteAsync("{\"acknowledged\":true}");
	}

	public async ValueTask DisposeAsync()
	{
		await _app.StopAsync();
		await _app.DisposeAsync();
		Requests.Dispose();
	}
}
