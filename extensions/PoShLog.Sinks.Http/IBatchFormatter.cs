using System.Collections.Generic;
using System.IO;

namespace PoShLog.Sinks.Http
{
    /// <summary>Combines formatted events into one HTTP request body.</summary>
    public interface IBatchFormatter
    {
        void Format(IEnumerable<string> logEvents, TextWriter output);
    }
}
