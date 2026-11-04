using System;
using Serilog.Events;
using Serilog.Expressions;

namespace PoShLog.Core.Utils
{
    internal static class ExpressionFilter
    {
        internal static Func<LogEvent, bool> Compile(string expression)
        {
            CompiledExpression evaluate;
            try { evaluate = SerilogExpression.Compile(expression); }
            catch (ArgumentException error)
            {
                throw new ArgumentException("Invalid Serilog filter expression.", nameof(expression), error);
            }
            return logEvent => evaluate(logEvent) is ScalarValue scalar && scalar.Value is bool result && result;
        }
    }
}
