using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Serilog;
using Serilog.Configuration;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting;
using Serilog.Sinks.Http;
using Serilog.Sinks.Http.BatchFormatters;
using Serilog.Sinks.Http.HttpClients;
using Serilog.Sinks.Http.TextFormatters;

namespace PoShLog.Sinks.Http.Compatibility
{
    // Http 9 limits queues by bytes. Native Serilog batching preserves the public
    // QueueLimit parameter's original event-count semantics instead.
    public sealed class CountLimitedHttpSink : IBatchedLogEventSink, IDisposable
    {
        private readonly string _uri;
        private readonly ITextFormatter _formatter;
        private readonly IBatchFormatter _batchFormatter;
        private readonly IHttpClient _client;

        private CountLimitedHttpSink(string uri, ITextFormatter formatter,
            IBatchFormatter batchFormatter, IHttpClient client, IConfiguration configuration)
        {
            _uri = uri;
            _formatter = formatter ?? new NormalRenderedTextFormatter();
            _batchFormatter = batchFormatter ?? new ArrayBatchFormatter();
            _client = client ?? new JsonHttpClient();
            if (configuration != null) _client.Configure(configuration);
        }

        public static LoggerConfiguration Configure(LoggerConfiguration logger, string uri,
            int batchPostingLimit, int? queueLimit, TimeSpan? period,
            ITextFormatter formatter, IBatchFormatter batchFormatter,
            LogEventLevel minimumLevel, IHttpClient client, IConfiguration configuration)
        {
            var options = new BatchingOptions
            {
                BatchSizeLimit = batchPostingLimit,
                QueueLimit = queueLimit,
                BufferingTimeLimit = period ?? TimeSpan.FromSeconds(2)
            };
            return logger.WriteTo.Sink(new CountLimitedHttpSink(uri, formatter,
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
            using var payload = new StringWriter();
            _batchFormatter.Format(events, payload);
            using var stream = new MemoryStream(Encoding.UTF8.GetBytes(payload.ToString()));
            using var response = await _client.PostAsync(_uri, stream, CancellationToken.None)
                .ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
        }

        public Task OnEmptyBatchAsync() => Task.CompletedTask;
        public void Dispose() => _client.Dispose();
    }
}
