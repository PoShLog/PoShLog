using System.Collections;
using System.Collections.ObjectModel;
using System.Globalization;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting;
using Serilog.Sinks.MSSqlServer;

namespace PoShLog.Sinks.MSSqlServer.Private;

public static class Sink
{
    public static void Configure(LoggerConfiguration logger, IDictionary settings)
    {
        var options = new MSSqlServerSinkOptions
        {
            TableName = (string)settings["TableName"]!, SchemaName = (string)settings["SchemaName"]!,
            AutoCreateSqlTable = (bool)settings["AutoCreateSqlTable"]!,
            BatchPostingLimit = (int)settings["BatchPostingLimit"]!, BatchPeriod = (TimeSpan)settings["BatchPeriod"]!,
            EagerlyEmitFirstEvent = (bool)settings["EagerlyEmitFirstEvent"]!,
            LevelSwitch = (LoggingLevelSwitch?)settings["LevelSwitch"]
        };
        var columns = CreateColumns((IDictionary?)settings["ColumnOptions"]);
        logger.WriteTo.MSSqlServer(connectionString: (string)settings["ConnectionString"]!, sinkOptions: options,
            restrictedToMinimumLevel: (LogEventLevel)settings["RestrictedToMinimumLevel"]!,
            formatProvider: (IFormatProvider?)settings["FormatProvider"], columnOptions: columns,
            logEventFormatter: (ITextFormatter?)settings["Formatter"]);
    }

    public static ColumnOptions CreateColumns(IDictionary? settings)
    {
        var columns = new ColumnOptions();
        if (settings == null) return columns;
        foreach (DictionaryEntry entry in settings)
        {
            var key = (string)entry.Key;
            if (key.Equals("Store", StringComparison.OrdinalIgnoreCase))
            {
                columns.Store.Clear();
                foreach (var value in Values(entry.Value))
                    columns.Store.Add(Enum.Parse<StandardColumn>(Convert.ToString(value, CultureInfo.InvariantCulture)!, true));
            }
            else if (key.Equals("AdditionalColumns", StringComparison.OrdinalIgnoreCase))
            {
                columns.AdditionalColumns = new Collection<SqlColumn>();
                foreach (var value in Values(entry.Value))
                {
                    if (value is not IDictionary data) throw new ArgumentException("AdditionalColumns must contain dictionaries.");
                    var column = new SqlColumn();
                    Apply(column, data);
                    if (string.IsNullOrWhiteSpace(column.ColumnName)) throw new ArgumentException("Additional columns need ColumnName.");
                    columns.AdditionalColumns.Add(column);
                }
            }
            else Apply(columns, new Hashtable { [key] = entry.Value });
        }
        return columns;
    }

    private static IEnumerable Values(object? value) => value is IEnumerable sequence && value is not string && value is not IDictionary
        ? sequence : new object?[] { value };

    private static void Apply(object target, IDictionary settings)
    {
        foreach (DictionaryEntry entry in settings)
        {
            var name = (string)entry.Key;
            var property = target.GetType().GetProperties().SingleOrDefault(p => p.Name.Equals(name, StringComparison.OrdinalIgnoreCase))
                ?? throw new ArgumentException($"Unknown column option: {name}.");
            if (entry.Value is IDictionary nested)
            {
                Apply(property.GetValue(target) ?? throw new ArgumentException($"Column option {name} cannot be nested."), nested);
                continue;
            }
            if (!property.CanWrite) throw new ArgumentException($"Column option {name} is read-only.");
            var type = Nullable.GetUnderlyingType(property.PropertyType) ?? property.PropertyType;
            var value = entry.Value;
            property.SetValue(target, value == null ? null : type.IsInstanceOfType(value) ? value : type.IsEnum
                ? Enum.Parse(type, Convert.ToString(value, CultureInfo.InvariantCulture)!, true)
                : Convert.ChangeType(value, type, CultureInfo.InvariantCulture));
        }
    }
}
