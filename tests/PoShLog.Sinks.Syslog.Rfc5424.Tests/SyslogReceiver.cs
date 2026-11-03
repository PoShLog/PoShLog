using System.Collections.Concurrent;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;

namespace PoShLog.Sinks.Syslog.Rfc5424.Tests;

/// <summary>
/// A loopback syslog server: UDP datagrams, or a TCP stream (optionally TLS with a self-signed certificate) whose bytes
/// are kept as they arrive, so tests can check the framing.
/// </summary>
public sealed class SyslogReceiver : IAsyncDisposable
{
	private readonly CancellationTokenSource _stop = new();
	private readonly UdpClient? _udp;
	private readonly TcpListener? _tcp;
	private readonly X509Certificate2? _certificate;
	private readonly MemoryStream _stream = new();
	private readonly Task _loop;

	/// <summary>Each UDP datagram, decoded as UTF-8.</summary>
	public ConcurrentQueue<string> Datagrams { get; } = new();

	public int Port { get; }

	/// <summary>The certificate of a TLS receiver.</summary>
	public X509Certificate2 Certificate => _certificate ?? throw new InvalidOperationException("Not a TLS receiver.");

	private SyslogReceiver(bool udp, bool tls)
	{
		if (udp)
		{
			_udp = new UdpClient(new IPEndPoint(IPAddress.Loopback, 0));
			Port = ((IPEndPoint)_udp.Client.LocalEndPoint!).Port;
			_loop = ReceiveDatagramsAsync();
			return;
		}
		if (tls)
		{
			_certificate = CreateCertificate();
		}
		_tcp = new TcpListener(IPAddress.Loopback, 0);
		_tcp.Start();
		Port = ((IPEndPoint)_tcp.LocalEndpoint).Port;
		_loop = AcceptAsync();
	}

	public static SyslogReceiver Udp() => new(udp: true, tls: false);

	public static SyslogReceiver Tcp() => new(udp: false, tls: false);

	public static SyslogReceiver Tls() => new(udp: false, tls: true);

	/// <summary>The TCP bytes received so far, as UTF-8 text.</summary>
	public string StreamText
	{
		get
		{
			lock (_stream)
			{
				return Encoding.UTF8.GetString(_stream.ToArray());
			}
		}
	}

	/// <summary>Splits octet-counted frames ("LEN SP MSG", RFC 6587) and checks each length in bytes.</summary>
	public IReadOnlyList<string> OctetCountedFrames()
	{
		byte[] bytes;
		lock (_stream)
		{
			bytes = _stream.ToArray();
		}
		var frames = new List<string>();
		var position = 0;
		while (position < bytes.Length)
		{
			var space = Array.IndexOf(bytes, (byte)' ', position);
			if (space < 0)
			{
				break;
			}
			var length = int.Parse(Encoding.ASCII.GetString(bytes, position, space - position));
			if (space + 1 + length > bytes.Length)
			{
				break;
			}
			frames.Add(Encoding.UTF8.GetString(bytes, space + 1, length));
			position = space + 1 + length;
		}
		return frames;
	}

	/// <summary>Waits until the received text (datagrams or stream) contains the marker.</summary>
	public async Task<bool> WaitForAsync(string marker, TimeSpan timeout)
	{
		var deadline = DateTime.UtcNow + timeout;
		while (DateTime.UtcNow < deadline)
		{
			if (Datagrams.Any(d => d.Contains(marker)) || StreamText.Contains(marker))
			{
				return true;
			}
			await Task.Delay(50);
		}
		return false;
	}

	private async Task ReceiveDatagramsAsync()
	{
		try
		{
			while (!_stop.IsCancellationRequested)
			{
				var result = await _udp!.ReceiveAsync(_stop.Token);
				Datagrams.Enqueue(Encoding.UTF8.GetString(result.Buffer));
			}
		}
		catch (Exception) when (_stop.IsCancellationRequested)
		{
		}
	}

	private async Task AcceptAsync()
	{
		var connections = new List<Task>();
		try
		{
			while (!_stop.IsCancellationRequested)
			{
				var client = await _tcp!.AcceptTcpClientAsync(_stop.Token);
				connections.Add(ReadAsync(client));
			}
		}
		catch (Exception) when (_stop.IsCancellationRequested)
		{
		}
		await Task.WhenAll(connections);
	}

	private async Task ReadAsync(TcpClient client)
	{
		using (client)
		{
			try
			{
				Stream stream = client.GetStream();
				if (_certificate is not null)
				{
					var tls = new SslStream(stream);
					await tls.AuthenticateAsServerAsync(new SslServerAuthenticationOptions { ServerCertificate = _certificate }, _stop.Token);
					stream = tls;
				}
				var buffer = new byte[8192];
				int read;
				while ((read = await stream.ReadAsync(buffer, _stop.Token)) > 0)
				{
					lock (_stream)
					{
						_stream.Write(buffer, 0, read);
					}
				}
			}
			catch (Exception)
			{
				// A client that gives up (an untrusted certificate) or the receiver stopping ends the connection.
			}
		}
	}

	private static X509Certificate2 CreateCertificate()
	{
		using var key = RSA.Create(2048);
		var request = new CertificateRequest("CN=localhost", key, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
		var names = new SubjectAlternativeNameBuilder();
		names.AddDnsName("localhost");
		names.AddIpAddress(IPAddress.Loopback);
		request.CertificateExtensions.Add(names.Build());
		using var certificate = request.CreateSelfSigned(DateTimeOffset.UtcNow.AddMinutes(-5), DateTimeOffset.UtcNow.AddHours(1));
		// SslStream on Windows needs a key it can use outside the ephemeral container.
		return new X509Certificate2(certificate.Export(X509ContentType.Pfx));
	}

	public async ValueTask DisposeAsync()
	{
		_stop.Cancel();
		_udp?.Dispose();
		_tcp?.Stop();
		try
		{
			await _loop.WaitAsync(TimeSpan.FromSeconds(5));
		}
		catch (Exception)
		{
		}
		_certificate?.Dispose();
		_stop.Dispose();
	}
}
