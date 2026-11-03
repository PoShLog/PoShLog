using Serilog;
using Serilog.Sinks.SystemConsole.Themes;

namespace PoShLog.UnitTests;

public class ConsoleThemeTests(PoShLogModuleFixture fixture) : PoShLogTestBase(fixture)
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "PoShLogIssues_" + Guid.NewGuid());

    private string Prepare()
    {
        Directory.CreateDirectory(directory);
        return directory.Replace("'", "''");
    }

    [Fact]
    public void Theme_CreatesAnsiStyles_AndCopiesInput()
    {
        var results = Invoke("$styles = @{ String = \"$([char]27)[32m\" }; $theme = New-ConsoleTheme -AnsiStyles $styles; $styles.String = 'changed'; $theme");
        var theme = Assert.IsType<AnsiConsoleTheme>(Assert.Single(results).BaseObject);
        using var writer = new StringWriter();
        theme.Set(writer, ConsoleThemeStyle.String);
        Assert.Equal("\u001b[32m", writer.ToString());
    }

    [Fact]
    public void Theme_CreatesSystemTheme()
    {
        var result = Invoke("New-ConsoleTheme -Foreground @{ String = 'Green'; Number = 'Cyan' } -Background @{ LevelError = 'DarkRed' }");
        Assert.IsType<SystemConsoleTheme>(Assert.Single(result).BaseObject);
    }

    [Fact]
    public void Theme_SystemColorsRetainForegroundAndBackground()
    {
        var result = Invoke("New-ConsoleTheme -Foreground @{ String = 'Green' } -Background @{ String = 'DarkBlue' }");
        var theme = Assert.IsType<SystemConsoleTheme>(Assert.Single(result).BaseObject);
        Assert.Equal(ConsoleColor.Green, theme.Styles[ConsoleThemeStyle.String].Foreground);
        Assert.Equal(ConsoleColor.DarkBlue, theme.Styles[ConsoleThemeStyle.String].Background);
    }

    [Theory]
    [InlineData("-AnsiStyles @{ NotAStyle = 'x' }")]
    [InlineData("-Foreground @{ String = 'NotAColor' }")]
    [InlineData("-Background @{ '999' = 'Red' }")]
    public void Theme_RejectsInvalidStyles(string arguments)
    {
        Invoke("New-ConsoleTheme " + arguments, allowErrors: true);
        Assert.NotNull(LastException);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }
}
