using System;
using Serilog.Events;
#if !NETFRAMEWORK
using Serilog.Expressions;
#endif

namespace PoShLog.Core.Utils
{
    internal static class ExpressionFilter
    {
        internal static Func<LogEvent, bool> Compile(string expression)
        {
#if NETFRAMEWORK
            throw new PlatformNotSupportedException("Expression filters are not supported on Windows PowerShell.");
#else
            CompiledExpression evaluate;
            try { evaluate = SerilogExpression.Compile(expression); }
            catch (ArgumentException error)
            {
                throw new ArgumentException("Invalid Serilog filter expression.", nameof(expression), error);
            }
            return logEvent => evaluate(logEvent) is ScalarValue scalar && scalar.Value is bool result && result;
#endif
        }
    }
}
