using System;
using System.Collections;
using Serilog;
using Serilog.Configuration;
using Serilog.Events;
using Serilog.Formatting;
using PoShLog.Sinks.Http.Compatibility;

namespace PoShLog.Sinks.Http
{
    public static class HttpSinkExtensions
    {
        /// <summary>Registers the native non-durable sink; queue limits count events.</summary>
        public static LoggerConfiguration Http(this LoggerSinkConfiguration sinks, string requestUri,
            int batchPostingLimit = 1000, int? queueLimit = 100000, TimeSpan? period = null,
            ITextFormatter formatter = null, IBatchFormatter batchFormatter = null,
            LogEventLevel restrictedToMinimumLevel = LogEventLevel.Verbose,
            IHttpClient httpClient = null, IDictionary configuration = null,
            long? queueLimitBytes = null)
        {
            // Retain JSON configuration explicitly supplying null to the former upstream API.
            if (queueLimitBytes != null)
                throw new ArgumentException("Use queueLimit (event count) instead of queueLimitBytes.", nameof(queueLimitBytes));
            if (sinks == null) throw new ArgumentNullException(nameof(sinks));
            return CountLimitedHttpSink.Register(sinks, requestUri, batchPostingLimit, queueLimit,
                period, formatter, batchFormatter, restrictedToMinimumLevel, httpClient, configuration);
        }
    }
}
