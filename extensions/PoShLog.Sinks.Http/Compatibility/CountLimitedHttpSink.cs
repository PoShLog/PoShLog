using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Serilog;
using Serilog.Configuration;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting;
using PoShLog.Sinks.Http.BatchFormatters;
using PoShLog.Sinks.Http.HttpClients;
using PoShLog.Sinks.Http.TextFormatters;

namespace PoShLog.Sinks.Http.Compatibility
{
    // Serilog owns admission, retry scheduling and the shutdown drain.
    public sealed class CountLimitedHttpSink : IBatchedLogEventSink, IDisposable
    {
        private readonly string _uri;
        private readonly ITextFormatter _formatter;
        private readonly IBatchFormatter _batchFormatter;
        private readonly IHttpClient _client;

        private CountLimitedHttpSink(string uri, ITextFormatter formatter,
            IBatchFormatter batchFormatter, IHttpClient client, IDictionary configuration)
        {
            _uri = uri;
            _formatter = formatter ?? new NormalRenderedTextFormatter();
            _batchFormatter = batchFormatter ?? new ArrayBatchFormatter();
            _client = client ?? new ApiKeyHttpClient();
            try { if (configuration != null) _client.Configure(configuration); }
            catch { _client.Dispose(); throw; }
        }

        public static LoggerConfiguration Configure(LoggerConfiguration logger, string uri,
            int batchPostingLimit, int? queueLimit, TimeSpan? period,
            ITextFormatter formatter, IBatchFormatter batchFormatter,
            LogEventLevel minimumLevel, IHttpClient client, IDictionary configuration)
        {
            if (logger == null) throw new ArgumentNullException(nameof(logger));
            return logger.WriteTo.Http(uri, batchPostingLimit, queueLimit, period,
                formatter, batchFormatter, minimumLevel, client, configuration);
        }

        internal static LoggerConfiguration Register(LoggerSinkConfiguration sinks, string uri,
            int batchPostingLimit, int? queueLimit, TimeSpan? period, ITextFormatter formatter,
            IBatchFormatter batchFormatter, LogEventLevel minimumLevel, IHttpClient client, IDictionary configuration)
        {
            if (!Uri.TryCreate(uri, UriKind.Absolute, out var address) ||
                (address.Scheme != Uri.UriSchemeHttp && address.Scheme != Uri.UriSchemeHttps))
                throw new ArgumentException("RequestUri must be an absolute HTTP or HTTPS URI.", nameof(uri));
            if (batchPostingLimit <= 0) throw new ArgumentOutOfRangeException(nameof(batchPostingLimit));
            if (queueLimit <= 0) throw new ArgumentOutOfRangeException(nameof(queueLimit));
            if (period <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(period));
            var options = new BatchingOptions
            {
                BatchSizeLimit = batchPostingLimit,
                QueueLimit = queueLimit,
                BufferingTimeLimit = period ?? TimeSpan.FromSeconds(2),
                EagerlyEmitFirstEvent = true
            };
            return sinks.Sink(new CountLimitedHttpSink(uri, formatter,
                batchFormatter, client, configuration), options, minimumLevel);
        }

        public async Task EmitBatchAsync(IReadOnlyCollection<LogEvent> batch)
        {
            var events = batch.Select(e =>
            {
                using var writer = new StringWriter();
                _formatter.Format(e, writer);
                return writer.ToString();
            }).ToArray();
            using var stream = new MemoryStream();
            using (var writer = new StreamWriter(stream, new UTF8Encoding(false), 1024, true))
                _batchFormatter.Format(events, writer);
            if (stream.Length == 0) return;
            stream.Position = 0;
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            using var response = await _client.PostAsync(_uri, stream, timeout.Token).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
        }

        public Task OnEmptyBatchAsync() => Task.CompletedTask;
        public void Dispose() => _client.Dispose();
    }
}
