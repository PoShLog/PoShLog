using PoShLog.Core.Utils;
using Serilog;
using Serilog.Configuration;

namespace PoShLog.Core.Sinks.Extensions
{
    /// <summary>Expression filter methods exposed to PoShLog's JSON configuration reader.</summary>
    public static class ExpressionFilterConfigurationExtensions
    {
        /// <summary>Include events only when a Serilog expression evaluates to Boolean true.</summary>
        public static LoggerConfiguration ByIncludingOnly(this LoggerFilterConfiguration configuration, string expression)
            => configuration.ByIncludingOnly(ExpressionFilter.Compile(expression));

        /// <summary>Exclude events when a Serilog expression evaluates to Boolean true.</summary>
        public static LoggerConfiguration ByExcluding(this LoggerFilterConfiguration configuration, string expression)
            => configuration.ByExcluding(ExpressionFilter.Compile(expression));
    }
}
