# New-ConsoleTheme

Creates a custom theme for the text overload of [Add-SinkConsole](Add-SinkConsole.md).

```powershell
New-ConsoleTheme -AnsiStyles <hashtable>
New-ConsoleTheme [-Foreground <hashtable>] [-Background <hashtable>]
```

Each hashtable maps a `ConsoleThemeStyle` name to a style. Names are case insensitive;
unknown names and numeric enum keys are rejected. Input tables are copied, and
unspecified tokens are uncolored. The two parameter sets cannot be combined.

`-AnsiStyles` values are strings containing ANSI escape sequences. `-Foreground`
and `-Background` values are `System.ConsoleColor` names (for example `Green`, `Cyan`,
`DarkRed`). A style may have both foreground and background colors.

```powershell
$theme = New-ConsoleTheme -AnsiStyles @{
    Text = "`e[37m"
    String = "`e[32m"
    Number = "`e[36m"
    LevelWarning = "`e[33m"
    LevelError = "`e[31m"
}
New-Logger | Add-SinkConsole -Theme $theme | Start-Logger
Write-InfoLog 'User {Name} has {Count} items' -PropertyValues 'Ada', 3
Close-Logger
```

Here the string `Ada` and number `3` have different colors from the message text.
For System console colors:

```powershell
$theme = New-ConsoleTheme -Foreground @{ String = 'Green'; Number = 'Cyan' } `
    -Background @{ LevelError = 'DarkRed' }
New-Logger | Add-SinkConsole -Theme $theme | Start-Logger
```

Supported token names: `Text`, `SecondaryText`, `TertiaryText`, `Invalid`, `Null`,
`Name`, `String`, `Number`, `Boolean`, `Scalar`, `LevelVerbose`, `LevelDebug`,
`LevelInformation`, `LevelWarning`, `LevelError`, `LevelFatal`. The upstream legacy
alias `Object` is accepted for `Scalar`. See [Serilog console themes](https://github.com/serilog/serilog-sinks-console#themes).

ANSI themes require a terminal that understands the sequences. Themes normally
disable coloring when output is redirected. `Add-SinkConsole -ApplyThemeToRedirectedOutput`
can force ANSI sequences for a consumer that understands them. System themes use
console foreground/background APIs and are intended for an interactive console.
Serilog respects the `NO_COLOR` environment variable even with this switch.

Themes style token types across events. They do not select a particular property by
name, or arbitrary substrings of a message. Use structured template arguments for
variable content; do not inject escape codes into values that also go to files or JSON.
`-Formatter` uses the formatter's output and does not apply `-Theme`.

Output: `Serilog.Sinks.SystemConsole.Themes.ConsoleTheme` (ANSI or System subtype).
