using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using Serilog.Sinks.SystemConsole.Themes;

namespace PoShLog.Core.Cmdlets.Helpers
{
    /// <summary>Build a Console sink theme from token styles, using ANSI escapes or System console colors.</summary>
    [Cmdlet(VerbsCommon.New, "ConsoleTheme", DefaultParameterSetName = "System")]
    [OutputType(typeof(ConsoleTheme))]
    public class NewConsoleThemeCommand : PSCmdlet
    {
        /// <summary>ConsoleThemeStyle names mapped to ANSI escape sequences. Unspecified styles are uncolored.</summary>
        [Parameter(Mandatory = true, ParameterSetName = "Ansi")]
        [ValidateNotNull]
        public Hashtable AnsiStyles { get; set; }

        /// <summary>ConsoleThemeStyle names mapped to ConsoleColor foreground names.</summary>
        [Parameter(ParameterSetName = "System")]
        [ValidateNotNull]
        public Hashtable Foreground { get; set; }

        /// <summary>ConsoleThemeStyle names mapped to ConsoleColor background names.</summary>
        [Parameter(ParameterSetName = "System")]
        [ValidateNotNull]
        public Hashtable Background { get; set; }

        private static T ParseName<T>(object value) where T : struct, Enum
        {
            var name = value?.ToString();
            // Reject numeric enum values, including otherwise valid numeric values.
            if (name == null || !Array.Exists(Enum.GetNames<T>(), n => string.Equals(n, name, StringComparison.OrdinalIgnoreCase)))
                throw new ArgumentException($"Invalid {typeof(T).Name} name.");
            return Enum.Parse<T>(name, ignoreCase: true);
        }

        protected override void ProcessRecord()
        {
            if (ParameterSetName == "Ansi")
            {
                var styles = new Dictionary<ConsoleThemeStyle, string>();
                foreach (DictionaryEntry entry in AnsiStyles)
                {
                    if (entry.Value is not string sequence)
                        throw new ArgumentException("ANSI styles must be strings containing ANSI escape sequences.");
                    styles.Add(ParseName<ConsoleThemeStyle>(entry.Key), sequence);
                }
                WriteObject(new AnsiConsoleTheme(styles));
                return;
            }

            var colors = new Dictionary<ConsoleThemeStyle, SystemConsoleThemeStyle>();
            if (Foreground != null)
                foreach (DictionaryEntry entry in Foreground)
                {
                    var style = ParseName<ConsoleThemeStyle>(entry.Key);
                    colors[style] = new SystemConsoleThemeStyle { Foreground = ParseName<ConsoleColor>(entry.Value) };
                }
            if (Background != null)
                foreach (DictionaryEntry entry in Background)
                {
                    var style = ParseName<ConsoleThemeStyle>(entry.Key);
                    colors.TryGetValue(style, out var color);
                    color.Background = ParseName<ConsoleColor>(entry.Value);
                    colors[style] = color;
                }
            WriteObject(new SystemConsoleTheme(colors));
        }
    }
}
