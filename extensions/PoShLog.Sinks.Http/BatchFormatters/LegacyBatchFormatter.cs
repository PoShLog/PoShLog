using System;
using System.Collections.Generic;
using System.IO;

namespace PoShLog.Sinks.Http.BatchFormatters
{
    /// <summary>Published 1.0.1 envelope with a configurable UTF-8 per-event limit.</summary>
    public sealed class LegacyBatchFormatter : IBatchFormatter
    {
        private readonly long? _eventBodyLimitBytes;
        // An explicit default constructor avoids PowerShell's optional Nullable<T> binding bug.
        public LegacyBatchFormatter() : this(256 * 1024) { }

        public LegacyBatchFormatter(long? eventBodyLimitBytes)
        {
            if (eventBodyLimitBytes <= 0) throw new ArgumentOutOfRangeException(nameof(eventBodyLimitBytes));
            _eventBodyLimitBytes = eventBodyLimitBytes;
        }

        public void Format(IEnumerable<string> logEvents, TextWriter output)
        {
            if (logEvents == null) throw new ArgumentNullException(nameof(logEvents));
            if (output == null) throw new ArgumentNullException(nameof(output));
            using var iterator = logEvents.GetEnumerator();
            if (!iterator.MoveNext()) return;
            output.Write("{\"events\":[");
            ArrayBatchFormatter.WriteEvents(iterator, output, _eventBodyLimitBytes);
            output.Write("]}");
        }
    }
}
