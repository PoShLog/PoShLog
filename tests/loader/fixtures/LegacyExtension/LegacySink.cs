using System.IO;
using Serilog;
using Serilog.Core;
using Serilog.Events;

public static class LegacyExtension
{
    public static Logger CreateLogger(string path)
    {
        return new LoggerConfiguration().WriteTo.Sink(new LegacySink(path)).CreateLogger();
    }

    private sealed class LegacySink : ILogEventSink
    {
        private readonly string path;
        internal LegacySink(string path) { this.path = path; }
        public void Emit(LogEvent logEvent) { File.AppendAllText(path, logEvent.RenderMessage()); }
    }
}
