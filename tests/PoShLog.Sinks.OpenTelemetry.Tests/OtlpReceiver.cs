using System.Collections.Concurrent;
using System.Net;
using System.Text;
using Google.Protobuf;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace PoShLog.Sinks.OpenTelemetry.Tests;

/// <summary>One export request as the receiver saw it.</summary>
public sealed record OtlpRequest(string Path, string ContentType, IReadOnlyDictionary<string, string> Headers, IReadOnlyList<string> Strings);

/// <summary>
/// A minimal local OTLP receiver: OTLP/HTTP on an HTTP/1.1 port and OTLP/gRPC on a cleartext HTTP/2 port, both on
/// loopback with ephemeral ports. It answers every export with success and keeps the strings found in the protobuf
/// body, which is enough to assert that an event, its attributes and its resource arrived.
/// </summary>
public sealed class OtlpReceiver : IAsyncDisposable
{
	public const string GrpcExportPath = "/opentelemetry.proto.collector.logs.v1.LogsService/Export";

	private readonly WebApplication _app;

	public BlockingCollection<OtlpRequest> Requests { get; } = new();
	public string HttpUrl { get; private set; } = "";
	public string GrpcUrl { get; private set; } = "";

	private OtlpReceiver(WebApplication app) => _app = app;

	public static async Task<OtlpReceiver> StartAsync()
	{
		var builder = WebApplication.CreateSlimBuilder();
		builder.Logging.ClearProviders();
		builder.WebHost.ConfigureKestrel(kestrel =>
		{
			kestrel.Listen(IPAddress.Loopback, 0, o => o.Protocols = HttpProtocols.Http1);
			kestrel.Listen(IPAddress.Loopback, 0, o => o.Protocols = HttpProtocols.Http2);
		});
		var app = builder.Build();
		var receiver = new OtlpReceiver(app);
		app.Run(receiver.HandleAsync);
		await app.StartAsync();

		var addresses = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.ToList();
		if (addresses.Count != 2)
		{
			throw new InvalidOperationException($"Expected two receiver addresses, got: {string.Join(", ", addresses)}");
		}
		// Kestrel lists the endpoints in the order they were configured.
		receiver.HttpUrl = addresses[0];
		receiver.GrpcUrl = addresses[1];
		return receiver;
	}

	/// <summary>Waits for a request whose strings contain <paramref name="marker"/>.</summary>
	public OtlpRequest WaitFor(string marker, TimeSpan timeout)
	{
		var deadline = DateTime.UtcNow + timeout;
		while (DateTime.UtcNow < deadline)
		{
			if (Requests.TryTake(out var request, TimeSpan.FromMilliseconds(100)) && request.Strings.Any(s => s.Contains(marker)))
			{
				return request;
			}
		}
		throw new TimeoutException($"No OTLP export containing '{marker}' arrived within {timeout}.");
	}

	private async Task HandleAsync(HttpContext context)
	{
		using var buffer = new MemoryStream();
		await context.Request.Body.CopyToAsync(buffer);
		var body = buffer.ToArray();
		var grpc = context.Request.ContentType?.StartsWith("application/grpc", StringComparison.Ordinal) == true;
		if (grpc)
		{
			// One length-prefixed message: compression flag (1 byte, 0 = none) and big-endian length (4 bytes).
			body = body.Length >= 5 ? body[5..] : Array.Empty<byte>();
		}

		var headers = context.Request.Headers.ToDictionary(h => h.Key.ToLowerInvariant(), h => h.Value.ToString());
		Requests.Add(new OtlpRequest(context.Request.Path, context.Request.ContentType ?? "", headers, ProtobufStrings.Read(body)));

		if (grpc)
		{
			context.Response.ContentType = "application/grpc";
			// An empty ExportLogsServiceResponse in one uncompressed frame, then the gRPC status trailer.
			await context.Response.Body.WriteAsync(new byte[5]);
			context.Response.AppendTrailer("grpc-status", "0");
		}
		else
		{
			context.Response.ContentType = "application/x-protobuf";
		}
	}

	public async ValueTask DisposeAsync()
	{
		await _app.StopAsync();
		await _app.DisposeAsync();
		Requests.Dispose();
	}
}

/// <summary>
/// Collects every string in a protobuf message without its schema: each length-delimited field is read as a nested
/// message when it parses as one, and kept as text when it is valid UTF-8.
/// </summary>
public static class ProtobufStrings
{
	private static readonly UTF8Encoding StrictUtf8 = new(false, true);

	public static IReadOnlyList<string> Read(byte[] message)
	{
		var strings = new List<string>();
		Walk(message, strings, 0);
		return strings;
	}

	private static void Walk(byte[] bytes, List<string> strings, int depth)
	{
		try
		{
			TryText(bytes, strings);
			if (depth < 16 && Parses(bytes))
			{
				var input = new CodedInputStream(bytes);
				uint tag;
				while ((tag = input.ReadTag()) != 0)
				{
					if (WireFormat.GetTagWireType(tag) == WireFormat.WireType.LengthDelimited)
					{
						Walk(input.ReadBytes().ToByteArray(), strings, depth + 1);
					}
					else
					{
						input.SkipLastField();
					}
				}
			}
		}
		catch (InvalidProtocolBufferException)
		{
			// Not a message; the text form (if any) was already kept.
		}
	}

	private static bool Parses(byte[] bytes)
	{
		try
		{
			var input = new CodedInputStream(bytes);
			uint tag;
			while ((tag = input.ReadTag()) != 0)
			{
				if (WireFormat.GetTagFieldNumber(tag) == 0)
				{
					return false;
				}
				input.SkipLastField();
			}
			return bytes.Length > 0;
		}
		catch (InvalidProtocolBufferException)
		{
			return false;
		}
	}

	private static void TryText(byte[] bytes, List<string> strings)
	{
		if (bytes.Length == 0)
		{
			return;
		}
		try
		{
			var text = StrictUtf8.GetString(bytes);
			if (text.All(c => !char.IsControl(c) || c is '\r' or '\n' or '\t'))
			{
				strings.Add(text);
			}
		}
		catch (DecoderFallbackException)
		{
		}
	}
}
