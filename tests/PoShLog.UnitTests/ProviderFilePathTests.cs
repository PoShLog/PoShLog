using Serilog;
using Serilog.Sinks.SystemConsole.Themes;

namespace PoShLog.UnitTests;

public class ProviderFilePathTests(PoShLogModuleFixture fixture) : PoShLogTestBase(fixture)
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "PoShLogIssues_" + Guid.NewGuid());

    private string Prepare()
    {
        Directory.CreateDirectory(directory);
        return directory.Replace("'", "''");
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public void FilePaths_UsePowerShellLocation(bool formatter, bool shortForm)
    {
        var path = Prepare();
        Invoke($"Set-Location '{path}'");
        Invoke(shortForm ? "Start-Logger -FilePath './relative.log'" :
            "New-Logger | Add-SinkFile -Path './relative.log' " +
            (formatter ? "-Formatter (Get-JsonFormatter) " : "") + "| Start-Logger");
        Invoke("Write-InfoLog 'relative message'; Close-Logger");
        Assert.Contains("relative message", File.ReadAllText(Path.Combine(directory, "relative.log")));
    }

    [Fact]
    public void FilePaths_ResolveFileSystemDrive()
    {
        var path = Prepare();
        Invoke($"New-PSDrive -Name IssueLogs -PSProvider FileSystem -Root '{path}' | Out-Null; New-Logger | Add-SinkFile -Path 'IssueLogs:/drive.log' | Start-Logger; Write-InfoLog 'drive message'; Close-Logger");
        Assert.Contains("drive message", File.ReadAllText(Path.Combine(directory, "drive.log")));
    }

    [Fact]
    public void FilePaths_RejectNonFileSystemProvider()
    {
        Invoke("New-Logger | Add-SinkFile -Path 'Variable:/issue.log'", allowErrors: true);
        Assert.NotNull(LastException);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }
}
