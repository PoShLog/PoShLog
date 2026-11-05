using System;
using System.Collections.Generic;
using System.IO;

namespace PoShLog.Sinks.Http.BatchFormatters
{
    /// <summary>Formats a non-empty sequence as a JSON array, skipping blank events.</summary>
    public class ArrayBatchFormatter : IBatchFormatter
    {
        public void Format(IEnumerable<string> logEvents, TextWriter output)
        {
            if (logEvents == null) throw new ArgumentNullException(nameof(logEvents));
            if (output == null) throw new ArgumentNullException(nameof(output));
            using var iterator = logEvents.GetEnumerator();
            if (!iterator.MoveNext()) return;
            output.Write("[");
            WriteEvents(iterator, output, null);
            output.Write("]");
        }

        internal static void WriteEvents(IEnumerator<string> iterator, TextWriter output, long? limit)
        {
            var separator = "";
            do
            {
                var item = iterator.Current;
                if (string.IsNullOrWhiteSpace(item)) continue;
                if (limit.HasValue && System.Text.Encoding.UTF8.GetByteCount(item) > limit.Value)
                {
                    Serilog.Debugging.SelfLog.WriteLine("HTTP event exceeds the legacy event body limit and was dropped.");
                    continue;
                }
                output.Write(separator);
                output.Write(item);
                separator = ",";
            } while (iterator.MoveNext());
        }
    }
}
