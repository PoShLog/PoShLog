using System.Collections;
using System.Data;
using PoShLog.Sinks.MSSqlServer.Private;
using Serilog.Sinks.MSSqlServer;

namespace PoShLog.Sinks.MSSqlServer.Tests;

public class ColumnOptionsTests
{
    [Fact]
    public void DefaultsMatchUpstream() => Assert.Equal(new ColumnOptions().Store, Sink.CreateColumns(null).Store);

    [Fact]
    public void StoreReplacesDefaultsAndAcceptsCaseInsensitiveNames()
    {
        var columns = Sink.CreateColumns(new Hashtable { ["store"] = new[] { "Message", "level", "LogEvent" } });
        Assert.Equal(new[] { StandardColumn.Message, StandardColumn.Level, StandardColumn.LogEvent }, columns.Store);
    }

    [Fact]
    public void SingleStandardColumnIsAccepted() => Assert.Equal(new[] { StandardColumn.LogEvent },
        Sink.CreateColumns(new Hashtable { ["Store"] = "LogEvent" }).Store);

    [Fact]
    public void AdditionalColumnMapsSqlTypePropertyAndLength()
    {
        var columns = Sink.CreateColumns(new Hashtable { ["AdditionalColumns"] = new[] {
            new Hashtable { ["ColumnName"] = "OrderId", ["PropertyName"] = "Order.Id", ["DataType"] = "NVarChar", ["DataLength"] = 80 }
        } });
        var column = Assert.Single(columns.AdditionalColumns);
        Assert.Equal("OrderId", column.ColumnName);
        Assert.Equal("Order.Id", column.PropertyName);
        Assert.Equal(SqlDbType.NVarChar, column.DataType);
        Assert.Equal(80, column.DataLength);
    }

    [Fact]
    public void NestedStandardOptionsAreApplied()
    {
        var columns = Sink.CreateColumns(new Hashtable {
            ["LogEvent"] = new Hashtable { ["ExcludeStandardColumns"] = true },
            ["TimeStamp"] = new Hashtable { ["ConvertToUtc"] = true },
            ["Level"] = new Hashtable { ["StoreAsEnum"] = true }
        });
        Assert.True(columns.LogEvent.ExcludeStandardColumns);
        Assert.True(columns.TimeStamp.ConvertToUtc);
        Assert.True(columns.Level.StoreAsEnum);
    }

    [Theory]
    [InlineData("NoSuchOption")]
    [InlineData("ConnectionString")]
    public void UnknownOptionsFailInsteadOfSilentlyDroppingData(string name) =>
        Assert.Throws<ArgumentException>(() => Sink.CreateColumns(new Hashtable { [name] = true }));

    [Fact]
    public void InvalidStandardColumnFails() => Assert.Throws<ArgumentException>(() =>
        Sink.CreateColumns(new Hashtable { ["Store"] = "Typo" }));

    [Fact]
    public void AdditionalColumnsMustBeDictionaries() => Assert.Throws<ArgumentException>(() =>
        Sink.CreateColumns(new Hashtable { ["AdditionalColumns"] = "Typo" }));

    [Fact]
    public void AdditionalColumnsNeedNames() => Assert.Throws<ArgumentException>(() =>
        Sink.CreateColumns(new Hashtable { ["AdditionalColumns"] = new Hashtable { ["DataType"] = "Int" } }));
}
