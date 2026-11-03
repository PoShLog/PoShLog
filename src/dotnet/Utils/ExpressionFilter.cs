using System;
using System.IO;
using System.Linq.Expressions;
using System.Reflection;
using System.Runtime.Loader;
using Serilog.Events;

namespace PoShLog.Core.Utils
{
    internal static class ExpressionFilter
    {
        // Keep expression-only helper types out of PowerShell's default type lookup. The published
        // Exceptionless wrapper uses the same Serilog.LoggerSinkConfigurationExtensions type name.
        private sealed class ExpressionLoadContext : AssemblyLoadContext
        {
            internal ExpressionLoadContext() : base("PoShLog.Expressions", isCollectible: false) { }

            protected override Assembly Load(AssemblyName name)
                => name.Name == "Serilog" ? typeof(LogEvent).Assembly : null;
        }

        private static readonly Lazy<MethodInfo> CompileMethod = new Lazy<MethodInfo>(() =>
        {
            var context = new ExpressionLoadContext();
            var assembly = context.LoadFromAssemblyPath(Path.Combine(
                Path.GetDirectoryName(typeof(ExpressionFilter).Assembly.Location), "Serilog.Expressions.dll"));
            return assembly.GetType("Serilog.Expressions.SerilogExpression", throwOnError: true).GetMethod("Compile");
        });

        internal static Func<LogEvent, bool> Compile(string expression)
        {
            Delegate compiled;
            try { compiled = (Delegate)CompileMethod.Value.Invoke(null, new object[] { expression, null, null }); }
            catch (TargetInvocationException error) when (error.InnerException is ArgumentException)
            {
                throw new ArgumentException("Invalid Serilog filter expression.", nameof(expression), error.InnerException);
            }
            // Adapt the isolated package's delegate once. No reflection, PowerShell, or runspace is
            // involved in evaluation. Serilog event/value types are shared with the default context.
            var parameter = Expression.Parameter(typeof(LogEvent), "logEvent");
            var evaluate = Expression.Lambda<Func<LogEvent, LogEventPropertyValue>>(
                Expression.Invoke(Expression.Constant(compiled), parameter), parameter).Compile();
            return logEvent => evaluate(logEvent) is ScalarValue scalar && scalar.Value is bool result && result;
        }
    }
}
