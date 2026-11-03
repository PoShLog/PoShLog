using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Serilog.Core;
using Serilog.Events;
using Serilog.Sinks.Syslog;

namespace PoShLog.Sinks.Syslog.Rfc5424
{
	// The package's own SyslogUdpSink and SyslogTcpSink implement PeriodicBatching's interface; these implement Serilog 4's,
	// so Serilog.Sinks.PeriodicBatching never loads (ADR 0014).

	/// <summary>Sends each message as one UDP datagram (RFC 5426).</summary>
	public sealed class SyslogUdpTransport : IBatchedLogEventSink, IDisposable
	{
		/// <summary>The largest UDP payload over IPv4; a longer message is cut at a character boundary.</summary>
		public const int MaxDatagramBytes = 65507;

		private readonly string _host;
		private readonly int _port;
		private readonly ISyslogFormatter _formatter;
		private UdpClient? _client;

		public SyslogUdpTransport(string host, int port, ISyslogFormatter formatter)
		{
			_host = host;
			_port = port;
			_formatter = formatter;
		}

		public async Task EmitBatchAsync(IReadOnlyCollection<LogEvent> batch)
		{
			try
			{
				// Resolved once per connection; a failed send resolves the name again on the next batch.
				_client ??= await ConnectAsync().ConfigureAwait(false);
				foreach (var logEvent in batch)
				{
					var datagram = Truncate(Encoding.UTF8.GetBytes(_formatter.FormatMessage(logEvent)));
					await _client.SendAsync(datagram).ConfigureAwait(false);
				}
			}
			catch
			{
				Reset();
				throw;
			}
		}

		/// <summary>Cuts a payload to <see cref="MaxDatagramBytes"/> without splitting a UTF-8 sequence.</summary>
		public static ReadOnlyMemory<byte> Truncate(byte[] payload)
		{
			if (payload.Length <= MaxDatagramBytes)
			{
				return payload;
			}
			var length = MaxDatagramBytes;
			while (length > 0 && (payload[length] & 0xC0) == 0x80)
			{
				length--;
			}
			return payload.AsMemory(0, length);
		}

		private async Task<UdpClient> ConnectAsync()
		{
			var address = await SyslogEndpoint.ResolveAsync(_host).ConfigureAwait(false);
			var client = new UdpClient(address.AddressFamily);
			client.Connect(new IPEndPoint(address, _port));
			return client;
		}

		private void Reset()
		{
			_client?.Dispose();
			_client = null;
		}

		public void Dispose() => Reset();
	}

	/// <summary>Writes framed messages to a TCP stream (RFC 6587), optionally over TLS (RFC 5425).</summary>
	public sealed class SyslogTcpTransport : IBatchedLogEventSink, IDisposable
	{
		/// <summary>The time allowed for connecting and the TLS handshake.</summary>
		public static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(30);

		private readonly string _host;
		private readonly int _port;
		private readonly ISyslogFormatter _formatter;
		private readonly MessageFramer _framer;
		private readonly bool _useTls;
		private readonly X509CertificateCollection? _clientCertificates;
		private readonly RemoteCertificateValidationCallback? _certificateValidation;
		private TcpClient? _client;
		private Stream? _stream;

		public SyslogTcpTransport(string host, int port, ISyslogFormatter formatter, MessageFramer framer, bool useTls,
			X509CertificateCollection? clientCertificates = null, RemoteCertificateValidationCallback? certificateValidation = null)
		{
			_host = host;
			_port = port;
			_formatter = formatter;
			_framer = framer;
			_useTls = useTls;
			_clientCertificates = clientCertificates;
			_certificateValidation = certificateValidation;
		}

		public async Task EmitBatchAsync(IReadOnlyCollection<LogEvent> batch)
		{
			try
			{
				// A closed or broken connection is opened again on the next batch; Serilog retries the failed one.
				_stream ??= await ConnectAsync().ConfigureAwait(false);
				foreach (var logEvent in batch)
				{
					await _framer.WriteFrame(_formatter.FormatMessage(logEvent), _stream).ConfigureAwait(false);
				}
				await _stream.FlushAsync().ConfigureAwait(false);
			}
			catch
			{
				Reset();
				throw;
			}
		}

		private async Task<Stream> ConnectAsync()
		{
			using var timeout = new CancellationTokenSource(ConnectTimeout);
			var address = await SyslogEndpoint.ResolveAsync(_host).ConfigureAwait(false);
			_client = new TcpClient(address.AddressFamily) { NoDelay = true };
			_client.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.KeepAlive, true);
			await _client.ConnectAsync(new IPEndPoint(address, _port), timeout.Token).ConfigureAwait(false);
			Stream stream = _client.GetStream();
			if (_useTls)
			{
				var tls = new SslStream(stream, leaveInnerStreamOpen: false);
				await tls.AuthenticateAsClientAsync(new SslClientAuthenticationOptions
				{
					TargetHost = _host,
					ClientCertificates = _clientCertificates,
					RemoteCertificateValidationCallback = _certificateValidation,
				}, timeout.Token).ConfigureAwait(false);
				stream = tls;
			}
			return stream;
		}

		private void Reset()
		{
			_stream?.Dispose();
			_stream = null;
			_client?.Dispose();
			_client = null;
		}

		public void Dispose() => Reset();
	}

	internal static class SyslogEndpoint
	{
		/// <summary>An IP literal as it is, otherwise the first IPv4 address of the name, or its first address.</summary>
		public static async Task<IPAddress> ResolveAsync(string host)
		{
			if (IPAddress.TryParse(host, out var literal))
			{
				return literal;
			}
			var addresses = await Dns.GetHostAddressesAsync(host).ConfigureAwait(false);
			if (addresses.Length == 0)
			{
				throw new SocketException((int)SocketError.HostNotFound);
			}
			return Array.Find(addresses, a => a.AddressFamily == AddressFamily.InterNetwork) ?? addresses[0];
		}
	}
}
