using Serilog.Core;
using Serilog.Events;

namespace PoShLog.UnitTests;

/// <summary>
/// Keeps every event it receives, so a test can assert on the structured properties instead of rendered text.
/// Scripts attach it with <c>$config.WriteTo.Sink($sink)</c>.
/// </summary>
public sealed class CollectingSink : ILogEventSink
{
    private readonly List<LogEvent> _events = new();

    public IReadOnlyList<LogEvent> Events
    {
        get
        {
            lock (_events)
            {
                return _events.ToList();
            }
        }
    }

    public void Emit(LogEvent logEvent)
    {
        lock (_events)
        {
            _events.Add(logEvent);
        }
    }
}
