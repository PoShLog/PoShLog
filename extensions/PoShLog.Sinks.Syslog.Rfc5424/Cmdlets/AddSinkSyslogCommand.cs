using System;
using System.Globalization;
using System.IO;
using System.Management.Automation;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using Serilog;
using Serilog.Configuration;
using Serilog.Core;
using Serilog.Events;
using Serilog.Sinks.Syslog;

namespace PoShLog.Sinks.Syslog.Rfc5424.Cmdlets
{
	/// <summary>
	/// <para type="synopsis">Writes log events to a syslog server over UDP, TCP or TLS.</para>
	/// <para type="description">Formats each event as an RFC 5424 (default) or RFC 3164 message. RFC 5424 messages carry the
	/// event's properties as structured data.</para>
	/// </summary>
	/// <example>
	/// <code>PS> New-Logger | Add-SinkSyslog -Hostname 'syslog.example.com' | Start-Logger</code>
	/// </example>
	[Cmdlet(VerbsCommon.Add, "SinkSyslog")]
	[OutputType(typeof(LoggerConfiguration))]
	public class AddSinkSyslogCommand : PSCmdlet
	{
		public const int DefaultBatchSizeLimit = 100;

		public static readonly TimeSpan DefaultBatchInterval = TimeSpan.FromSeconds(2);

		public const int DefaultQueueLimit = 100000;

		[Parameter(Mandatory = true, ValueFromPipeline = true)]
		public LoggerConfiguration LoggerConfig { get; set; } = null!;

		/// <summary><para type="description">The name or IP address of the syslog server.</para></summary>
		[Parameter(Mandatory = true, Position = 0)]
		[ValidateNotNullOrEmpty]
		public string Hostname { get; set; } = "";

		/// <summary><para type="description">The server port: 514 for Udp and Tcp, 6514 for TcpTls by default.</para></summary>
		[Parameter]
		[ValidateRange(1, 65535)]
		public int? Port { get; set; }

		/// <summary><para type="description">Udp (default), Tcp or TcpTls.</para></summary>
		[Parameter]
		public SyslogProtocol Protocol { get; set; } = SyslogProtocol.Udp;

		/// <summary><para type="description">Rfc5424 (default) or Rfc3164.</para></summary>
		[Parameter]
		public SyslogMessageFormat Format { get; set; } = SyslogMessageFormat.Rfc5424;

		/// <summary><para type="description">How messages are delimited on Tcp and TcpTls: OctetCounting (default), Lf, CrLf, Cr or Nul.</para></summary>
		[Parameter]
		public SyslogFraming Framing { get; set; } = SyslogFraming.OctetCounting;

		/// <summary><para type="description">The APP-NAME field: the calling script's name by default, otherwise the process name.</para></summary>
		[Parameter]
		public string? AppName { get; set; }

		/// <summary><para type="description">The syslog facility (default Local0).</para></summary>
		[Parameter]
		public Facility Facility { get; set; } = Facility.Local0;

		/// <summary><para type="description">The HOSTNAME field; the machine name by default.</para></summary>
		[Parameter]
		public string? SourceHost { get; set; }

		/// <summary><para type="description">The event property written as MSGID (RFC 5424; default SourceContext).</para></summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string MessageIdPropertyName { get; set; } = "SourceContext";

		/// <summary><para type="description">The SD-ID of the structured data element with the event's properties (RFC 5424).</para></summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string StructuredDataId { get; set; } = SyslogSinkSettings.DefaultStructuredDataId;

		/// <summary><para type="description">The MSG text (default "{Message:lj}{NewLine}{Exception}").</para></summary>
		[Parameter]
		public string? OutputTemplate { get; set; }

		[Parameter]
		public IFormatProvider? FormatProvider { get; set; }

		/// <summary><para type="description">Client certificates presented to the server (TcpTls only).</para></summary>
		[Parameter]
		public X509Certificate[]? ClientCertificate { get; set; }

		/// <summary><para type="description">Validates the server certificate instead of the system's trust store (TcpTls only).</para></summary>
		[Parameter]
		[Alias("CertValidationCallback")]
		public RemoteCertificateValidationCallback? CertificateValidationCallback { get; set; }

		/// <summary>
		/// <para type=description>Also trusts a server certificate with one of these SHA-1 or SHA-256 thumbprints, such as a
		/// self-signed one (TcpTls only).</para>
		/// </summary>
		[Parameter]
		[ValidateNotNullOrEmpty]
		public string[]? TrustedCertificateThumbprint { get; set; }

		[Parameter]
		public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;

		[Parameter]
		public LoggingLevelSwitch? LevelSwitch { get; set; }

		/// <summary><para type="description">How long events are buffered before they are sent (default 2 seconds). A number means seconds.</para></summary>
		[Parameter]
		[SecondsToTimeSpan]
		public TimeSpan? BatchInterval { get; set; }

		/// <summary><para type="description">Maximum events per batch (default 100).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? BatchSizeLimit { get; set; }

		/// <summary><para type="description">Maximum events waiting to be sent; later ones are dropped (default 100000).</para></summary>
		[Parameter]
		[ValidateRange(1, int.MaxValue)]
		public int? QueueLimit { get; set; }

		/// <inheritdoc />
		protected override void ProcessRecord()
		{
			var settings = new SyslogSinkSettings
			{
				Hostname = Hostname,
				Port = Port,
				Protocol = Protocol,
				Format = Format,
				Framing = Framing,
				AppName = AppName ?? ScriptAppName(),
				Facility = Facility,
				SourceHost = SourceHost,
				MessageIdPropertyName = MessageIdPropertyName,
				StructuredDataId = StructuredDataId,
				OutputTemplate = OutputTemplate,
				FormatProvider = FormatProvider,
			};
			var interval = BatchInterval ?? DefaultBatchInterval;

			IBatchedLogEventSink sink;
			try
			{
				if (interval <= TimeSpan.Zero)
				{
					throw new ArgumentException($"BatchInterval must be positive, not {interval}.");
				}
				RejectOptionsOfOtherModes();
				var port = settings.ResolvePort();
				var formatter = settings.CreateFormatter();
				if (TrustedCertificateThumbprint is not null && CertificateValidationCallback is not null)
				{
					throw new ArgumentException("Use either -TrustedCertificateThumbprint or -CertificateValidationCallback.");
				}
				var validation = TrustedCertificateThumbprint is null
					? CertificateValidationCallback
					: SyslogSinkSettings.PinnedCertificates(TrustedCertificateThumbprint);
				sink = Protocol == SyslogProtocol.Udp
					? new SyslogUdpTransport(Hostname, port, formatter)
					: new SyslogTcpTransport(Hostname, port, formatter, settings.CreateFramer(), Protocol == SyslogProtocol.TcpTls,
						ClientCertificate is null ? null : new X509CertificateCollection(ClientCertificate), validation);
			}
			catch (ArgumentException exception)
			{
				ThrowTerminatingError(new ErrorRecord(exception, "InvalidSyslogSinkArgument", ErrorCategory.InvalidArgument, Hostname));
				return;
			}

			var batching = new BatchingOptions
			{
				BatchSizeLimit = BatchSizeLimit ?? DefaultBatchSizeLimit,
				BufferingTimeLimit = interval,
				EagerlyEmitFirstEvent = true,
				QueueLimit = QueueLimit ?? DefaultQueueLimit,
			};
			LoggerConfig.WriteTo.Sink(sink, batching, RestrictedToMinimumLevel, LevelSwitch);

			WriteObject(LoggerConfig);
		}

		/// <summary>An option that the chosen protocol or format would silently ignore is an error.</summary>
		private void RejectOptionsOfOtherModes()
		{
			var bound = MyInvocation.BoundParameters;
			if (Protocol == SyslogProtocol.Udp && bound.ContainsKey(nameof(Framing)))
			{
				throw new ArgumentException("-Framing applies to -Protocol Tcp and TcpTls; UDP sends one message per datagram.");
			}
			if (Protocol != SyslogProtocol.TcpTls && (bound.ContainsKey(nameof(ClientCertificate)) || bound.ContainsKey(nameof(CertificateValidationCallback)) ||
				bound.ContainsKey(nameof(TrustedCertificateThumbprint))))
			{
				throw new ArgumentException("-ClientCertificate, -TrustedCertificateThumbprint and -CertificateValidationCallback apply to -Protocol TcpTls only.");
			}
			if (Format == SyslogMessageFormat.Rfc3164 && (bound.ContainsKey(nameof(StructuredDataId)) || bound.ContainsKey(nameof(MessageIdPropertyName))))
			{
				throw new ArgumentException("-StructuredDataId and -MessageIdPropertyName apply to -Format Rfc5424 only.");
			}
		}

		/// <summary>The calling script's file name, which tells scripts apart better than "pwsh".</summary>
		private string? ScriptAppName()
		{
			var script = MyInvocation.ScriptName;
			return string.IsNullOrEmpty(script) ? null : Path.GetFileNameWithoutExtension(script);
		}
	}

	/// <summary>Reads a bare number as seconds.</summary>
	public sealed class SecondsToTimeSpanAttribute : ArgumentTransformationAttribute
	{
		public override object? Transform(EngineIntrinsics engineIntrinsics, object? inputData)
		{
			var value = inputData is PSObject psObject ? psObject.BaseObject : inputData;
			return value switch
			{
				int seconds => TimeSpan.FromSeconds(seconds),
				long seconds => TimeSpan.FromSeconds(seconds),
				double seconds => TimeSpan.FromSeconds(seconds),
				decimal seconds => TimeSpan.FromSeconds((double)seconds),
				// "5" would otherwise parse as five days.
				string text when double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var seconds) => TimeSpan.FromSeconds(seconds),
				_ => inputData,
			};
		}
	}
}
