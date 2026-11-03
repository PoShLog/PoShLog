using System;
using System.IO;
using System.Linq;
using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using Serilog.Events;
using Serilog.Formatting;
using Serilog.Formatting.Display;
using Serilog.Sinks.Syslog;

namespace PoShLog.Sinks.Syslog.Rfc5424
{
	/// <summary>The transport to the syslog server.</summary>
	public enum SyslogProtocol
	{
		/// <summary>One datagram per message (RFC 5426).</summary>
		Udp,

		/// <summary>A plain TCP stream (RFC 6587).</summary>
		Tcp,

		/// <summary>TCP with TLS (RFC 5425).</summary>
		TcpTls,
	}

	/// <summary>The message format.</summary>
	public enum SyslogMessageFormat
	{
		/// <summary>The BSD format: &lt;PRI&gt;Mmm dd hh:mm:ss HOST APP[PID]: MSG.</summary>
		Rfc3164,

		/// <summary>The structured format: &lt;PRI&gt;1 TIMESTAMP HOST APP PROCID MSGID [SD] MSG.</summary>
		Rfc5424,
	}

	/// <summary>How messages are delimited on a TCP stream.</summary>
	public enum SyslogFraming
	{
		/// <summary>The message length and a space before each message (RFC 6587 octet counting).</summary>
		OctetCounting,

		/// <summary>A line feed after each message.</summary>
		Lf,

		/// <summary>A carriage return and a line feed after each message.</summary>
		CrLf,

		/// <summary>A carriage return after each message.</summary>
		Cr,

		/// <summary>A NUL byte after each message.</summary>
		Nul,
	}

	/// <summary>Turns the cmdlet's parameters into a syslog formatter, framer and endpoint.</summary>
	public sealed class SyslogSinkSettings
	{
		/// <summary>The IANA syslog port for UDP and plain TCP.</summary>
		public const int SyslogPort = 514;

		/// <summary>The IANA port for syslog over TLS (RFC 5425).</summary>
		public const int SyslogTlsPort = 6514;

		/// <summary>
		/// The SD-ID of the structured data element that carries the event's properties. The package leaves it empty, which
		/// RFC 5424 does not allow; 32473 is the enterprise number reserved for documentation (RFC 5612).
		/// </summary>
		public const string DefaultStructuredDataId = "poshlog@32473";

		/// <summary>The message text: the rendered message without quoted strings, then an exception on the next lines.</summary>
		public const string DefaultOutputTemplate = "{Message:lj}{NewLine}{Exception}";

		public string Hostname { get; set; } = "";

		public int? Port { get; set; }

		public SyslogProtocol Protocol { get; set; } = SyslogProtocol.Udp;

		public SyslogMessageFormat Format { get; set; } = SyslogMessageFormat.Rfc5424;

		public SyslogFraming Framing { get; set; } = SyslogFraming.OctetCounting;

		public string? AppName { get; set; }

		public Facility Facility { get; set; } = Facility.Local0;

		public string? SourceHost { get; set; }

		public string MessageIdPropertyName { get; set; } = "SourceContext";

		public string StructuredDataId { get; set; } = DefaultStructuredDataId;

		public string? OutputTemplate { get; set; }

		public IFormatProvider? FormatProvider { get; set; }

		/// <summary>The port, or the default of the protocol.</summary>
		public int ResolvePort()
		{
			var port = Port ?? (Protocol == SyslogProtocol.TcpTls ? SyslogTlsPort : SyslogPort);
			if (port is < 1 or > 65535)
			{
				throw new ArgumentException($"Port must be between 1 and 65535, not {port}.");
			}
			return port;
		}

		/// <summary>The RFC 3164 or RFC 5424 formatter of Serilog.Sinks.SyslogMessages.</summary>
		public ISyslogFormatter CreateFormatter()
		{
			if (string.IsNullOrWhiteSpace(Hostname))
			{
				throw new ArgumentException("Hostname must name the syslog server.");
			}
			ITextFormatter template = new TrimEndFormatter(new MessageTemplateTextFormatter(OutputTemplate ?? DefaultOutputTemplate, FormatProvider));
			var appName = string.IsNullOrWhiteSpace(AppName) ? null : AppName;
			var sourceHost = string.IsNullOrWhiteSpace(SourceHost) ? null : SourceHost;
			if (Format == SyslogMessageFormat.Rfc3164)
			{
				return new Rfc3164Formatter(Facility, appName, template, sourceHost, MapSeverity);
			}
			if (string.IsNullOrWhiteSpace(StructuredDataId) || StructuredDataId.IndexOfAny([' ', '=', ']', '"']) >= 0)
			{
				throw new ArgumentException($"'{StructuredDataId}' is not a valid RFC 5424 SD-ID (no spaces, '=', ']' or '\"').");
			}
			return new Rfc5424Formatter(Facility, appName, template, MessageIdPropertyName, sourceHost, MapSeverity, StructuredDataId);
		}

		/// <summary>
		/// The syslog severity of a Serilog level. The package maps Verbose to Notice, above Information, and Fatal to Emergency,
		/// which rsyslog's default rules broadcast to every logged-in terminal; a script's fatal error is Critical.
		/// </summary>
		public static Severity MapSeverity(LogEventLevel level) => level switch
		{
			LogEventLevel.Verbose or LogEventLevel.Debug => Severity.Debug,
			LogEventLevel.Information => Severity.Informational,
			LogEventLevel.Warning => Severity.Warning,
			LogEventLevel.Error => Severity.Error,
			_ => Severity.Critical,
		};

		/// <summary>
		/// Accepts the system's trust decision, or a server certificate whose SHA-1 or SHA-256 thumbprint is listed: the way
		/// to trust a self-signed syslog server from a script, where a script block callback would have no runspace.
		/// </summary>
		public static RemoteCertificateValidationCallback PinnedCertificates(string[] thumbprints)
		{
			var pinned = thumbprints.Select(Normalize).ToHashSet(StringComparer.OrdinalIgnoreCase);
			if (pinned.Count == 0 || pinned.Any(p => p.Length is not (40 or 64) || !p.All(Uri.IsHexDigit)))
			{
				throw new ArgumentException("-TrustedCertificateThumbprint takes SHA-1 (40) or SHA-256 (64) hex thumbprints.");
			}
			return (_, certificate, _, errors) =>
			{
				if (errors == SslPolicyErrors.None)
				{
					return true;
				}
				if (certificate is null)
				{
					return false;
				}
				var raw = certificate.GetRawCertData();
				return pinned.Contains(Convert.ToHexString(SHA1.HashData(raw))) || pinned.Contains(Convert.ToHexString(SHA256.HashData(raw)));
			};
		}

		private static string Normalize(string thumbprint) => new(thumbprint.Where(c => !char.IsWhiteSpace(c) && c != ':').ToArray());

		/// <summary>The TCP framer; UDP sends one message per datagram and needs none.</summary>
		public MessageFramer CreateFramer() => new(Framing switch
		{
			SyslogFraming.Lf => FramingType.LF,
			SyslogFraming.CrLf => FramingType.CRLF,
			SyslogFraming.Cr => FramingType.CR,
			SyslogFraming.Nul => FramingType.NUL,
			_ => FramingType.OCTET_COUNTING,
		});
	}

	/// <summary>
	/// Drops the line break that {NewLine}{Exception} leaves after a message without an exception; on a stream with line
	/// framing it would read as an empty message.
	/// </summary>
	public sealed class TrimEndFormatter : ITextFormatter
	{
		private readonly ITextFormatter _inner;

		public TrimEndFormatter(ITextFormatter inner) => _inner = inner;

		public void Format(LogEvent logEvent, TextWriter output)
		{
			using var buffer = new StringWriter();
			_inner.Format(logEvent, buffer);
			output.Write(buffer.ToString().TrimEnd('\r', '\n'));
		}
	}
}
