using System.Collections;
using System.Management.Automation;
using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Runtime.Loader;
using System.Text.Json;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting;

namespace PoShLog.Sinks.MSSqlServer;

/// <summary>Configures the SQL Server sink without exposing private dependency types to PowerShell.</summary>
[Cmdlet(VerbsCommon.Add, "SinkMSSqlServer")]
[OutputType(typeof(LoggerConfiguration))]
public sealed class AddSinkMSSqlServerCommand : PSCmdlet
{
    [Parameter(Mandatory = true, ValueFromPipeline = true)]
    public LoggerConfiguration LoggerConfig { get; set; } = null!;

    [Parameter(Mandatory = true)]
    [Alias("cnn")]
    [ValidateNotNullOrEmpty]
    public string ConnectionString { get; set; } = "";

    [Parameter][ValidateNotNullOrEmpty]
    public string TableName { get; set; } = "LogEvents";
    [Parameter][ValidateNotNullOrEmpty]
    public string SchemaName { get; set; } = "dbo";
    [Parameter] public SwitchParameter AutoCreateSqlTable { get; set; }
    [Parameter][ValidateRange(1, int.MaxValue)]
    public int BatchPostingLimit { get; set; } = 50;
    [Parameter] public TimeSpan BatchPeriod { get; set; } = TimeSpan.FromSeconds(5);
    [Parameter] public bool EagerlyEmitFirstEvent { get; set; } = true;
    [Parameter] public LogEventLevel RestrictedToMinimumLevel { get; set; } = LogEventLevel.Verbose;
    [Parameter] public LoggingLevelSwitch? LevelSwitch { get; set; }
    [Parameter] public ITextFormatter? Formatter { get; set; }
    [Parameter] public IFormatProvider? FormatProvider { get; set; }

    /// <summary>Data-only column settings: Store, AdditionalColumns and nested standard column options.</summary>
    [Parameter] public IDictionary? ColumnOptions { get; set; }

    protected override void ProcessRecord()
    {
        if (BatchPeriod <= TimeSpan.Zero)
            throw new PSArgumentException("BatchPeriod must be positive.");
        // Only shared Serilog and framework types cross the load-context boundary.
        var settings = new Hashtable
        {
            ["ConnectionString"] = ConnectionString, ["TableName"] = TableName, ["SchemaName"] = SchemaName,
            ["AutoCreateSqlTable"] = AutoCreateSqlTable.IsPresent, ["BatchPostingLimit"] = BatchPostingLimit,
            ["BatchPeriod"] = BatchPeriod, ["EagerlyEmitFirstEvent"] = EagerlyEmitFirstEvent,
            ["RestrictedToMinimumLevel"] = RestrictedToMinimumLevel, ["LevelSwitch"] = LevelSwitch,
            ["Formatter"] = Formatter, ["FormatProvider"] = FormatProvider, ["ColumnOptions"] = ColumnOptions
        };
        try { IsolatedSink.Configure.Invoke(null, new object[] { LoggerConfig, settings }); }
        catch (TargetInvocationException exception) when (exception.InnerException != null)
        {
            // Connection strings must never appear as ErrorRecord targets or in wrapper diagnostics.
            ExceptionDispatchInfo.Capture(exception.InnerException).Throw();
        }
        catch (TypeInitializationException exception) when (exception.InnerException != null)
        {
            // A missing or broken private worker surfaces its own message ("Missing private MSSqlServer dependency"),
            // not "The type initializer for 'IsolatedSink' threw an exception".
            ExceptionDispatchInfo.Capture(exception.InnerException).Throw();
        }
        WriteObject(LoggerConfig);
    }
}

internal static class IsolatedSink
{
    private static readonly SinkLoadContext Context = new();
    internal static readonly MethodInfo Configure = Context.LoadFromAssemblyPath(Context.WorkerPath)
        .GetType("PoShLog.Sinks.MSSqlServer.Private.Sink", throwOnError: true)!.GetMethod("Configure")!;
}

/// <summary>Shares Serilog explicitly, resolves all other packages privately, and leaves framework binding to the host.</summary>
internal sealed class SinkLoadContext : AssemblyLoadContext
{
    internal string WorkerPath { get; } = Path.Combine(Path.GetDirectoryName(typeof(SinkLoadContext).Assembly.Location)!,
        "private", "PoShLog.Sinks.MSSqlServer.Worker.dll");
    private readonly AssemblyDependencyResolver resolver;
    private readonly HashSet<string> packageAssemblies = new(StringComparer.OrdinalIgnoreCase);

    internal SinkLoadContext() : base("PoShLog.Sinks.MSSqlServer", isCollectible: false)
    {
        resolver = new AssemblyDependencyResolver(WorkerPath);
        using var dependencies = JsonDocument.Parse(File.ReadAllText(Path.ChangeExtension(WorkerPath, ".deps.json")));
        foreach (var target in dependencies.RootElement.GetProperty("targets").EnumerateObject())
        foreach (var library in target.Value.EnumerateObject())
        foreach (var group in library.Value.EnumerateObject().Where(p => p.Name is "runtime" or "runtimeTargets"))
        foreach (var asset in group.Value.EnumerateObject())
        {
            if (asset.Name.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
                packageAssemblies.Add(Path.GetFileNameWithoutExtension(asset.Name));
        }
    }

    protected override Assembly? Load(AssemblyName name)
    {
        if (name.Name == "Serilog") return typeof(LoggerConfiguration).Assembly;
        // LogEvent exposes ActivityTraceId/ActivitySpanId from this framework assembly.
        // A private copy would make those signatures incompatible with the shared Serilog.
        if (name.Name == "System.Diagnostics.DiagnosticSource") return typeof(System.Diagnostics.Activity).Assembly;
        var path = resolver.ResolveAssemblyToPath(name);
        if (path != null) return LoadFromAssemblyPath(path);
        if (packageAssemblies.Contains(name.Name!))
            throw MissingDependency(name);
        if (name.Name == "netstandard" || name.Name == "mscorlib" || name.Name == "System" ||
            name.Name!.StartsWith("System.", StringComparison.Ordinal) ||
            name.Name.StartsWith("Microsoft.Win32.", StringComparison.Ordinal)) return null;
        // Do not silently bind a missing private package to an unrelated module's assembly.
        throw MissingDependency(name);
    }

    private static FileNotFoundException MissingDependency(AssemblyName name) =>
        new($"Missing private MSSqlServer dependency: {name.Name}. Rebuild or reinstall the module.");

    protected override IntPtr LoadUnmanagedDll(string name)
    {
        var path = resolver.ResolveUnmanagedDllToPath(name);
        return path == null ? IntPtr.Zero : LoadUnmanagedDllFromPath(path);
    }
}
