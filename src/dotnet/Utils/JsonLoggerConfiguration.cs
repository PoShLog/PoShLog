using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Reflection;
using System.Runtime.CompilerServices;
#if !NETFRAMEWORK
using System.Runtime.Loader;
#endif
using System.Text.Json;
using Serilog;
using Serilog.Events;

namespace PoShLog.Core.Utils
{
    // ADR 0028: a bounded Serilog-schema reader avoids Microsoft.Extensions.Configuration
    // assemblies shipped by the published Http extension (ADR 0011).
    internal static class JsonLoggerConfiguration
    {
        internal static void Apply(LoggerConfiguration logger, string path, SessionState sessionState)
        {
            using var stream = File.OpenRead(path);
            using var document = JsonDocument.Parse(stream);
            if (document.RootElement.ValueKind != JsonValueKind.Object ||
                !document.RootElement.TryGetProperty("Serilog", out var section) || section.ValueKind != JsonValueKind.Object)
                throw new ArgumentException("The JSON configuration must contain a Serilog object.");
            ValidateKeys(section, "Using", "MinimumLevel", "Properties", "WriteTo", "Enrich", "Filter");
#if NETFRAMEWORK
            if (section.TryGetProperty("Filter", out var filters) && ArrayItems(filters, "Filter").Any())
                throw new PlatformNotSupportedException("JSON filters are not supported on Windows PowerShell.");
#endif

            // Include core methods even when their assemblies have not been used by a cmdlet yet.
            var assemblies = AppDomain.CurrentDomain.GetAssemblies().Concat(new[] {
                typeof(ConsoleLoggerConfigurationExtensions).Assembly,
                typeof(FileLoggerConfigurationExtensions).Assembly
            }).Where(a => !a.IsDynamic
#if !NETFRAMEWORK
                && AssemblyLoadContext.GetLoadContext(a) == AssemblyLoadContext.Default
#endif
            ).Distinct().ToArray();
            if (section.TryGetProperty("Using", out var usingSection))
                foreach (var name in ArrayItems(usingSection, "Using"))
                    if (!assemblies.Any(a => a.GetName().Name == name.GetString()))
                        throw new ArgumentException("A Using assembly is not loaded. Import its extension module first.");

            if (section.TryGetProperty("MinimumLevel", out var minimum))
            {
                if (minimum.ValueKind == JsonValueKind.String) logger.MinimumLevel.Is(Level(minimum));
                else
                {
                    ValidateKeys(minimum, "Default", "Override");
                    if (minimum.TryGetProperty("Default", out var value)) logger.MinimumLevel.Is(Level(value));
                    if (minimum.TryGetProperty("Override", out var overrides))
                        foreach (var item in overrides.EnumerateObject()) logger.MinimumLevel.Override(item.Name, Level(item.Value));
                }
            }
            if (section.TryGetProperty("Properties", out var properties))
                foreach (var property in properties.EnumerateObject())
                    logger.Enrich.WithProperty(property.Name, PropertyValue(property.Value), destructureObjects: true);

            var methods = assemblies.Where(a => a.GetName().Name == "Serilog" ||
                    a.GetReferencedAssemblies().Any(r => r.Name == "Serilog"))
                .SelectMany(ExportedTypes).Where(t => t.IsAbstract && t.IsSealed)
                .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Static))
                .Where(m => !m.ContainsGenericParameters && m.IsDefined(typeof(ExtensionAttribute), false) &&
                    m.ReturnType == typeof(LoggerConfiguration)).ToArray();
            Configure(section, "Enrich", logger.Enrich, methods, sessionState);
            Configure(section, "Filter", logger.Filter, methods, sessionState);
            Configure(section, "WriteTo", logger.WriteTo, methods, sessionState);
        }

        private static IEnumerable<Type> ExportedTypes(Assembly assembly)
        {
            try { return assembly.GetExportedTypes(); }
            catch (ReflectionTypeLoadException error) { return error.Types.Where(t => t != null && t.IsVisible); }
        }

        private static void Configure(JsonElement section, string key, object target, MethodInfo[] methods, SessionState sessionState)
        {
            if (!section.TryGetProperty(key, out var calls)) return;
            foreach (var call in ArrayItems(calls, key))
            {
                string name;
                var arguments = new Dictionary<string, JsonElement>(StringComparer.OrdinalIgnoreCase);
                if (call.ValueKind == JsonValueKind.String) name = call.GetString();
                else
                {
                    ValidateKeys(call, "Name", "Args");
                    if (!call.TryGetProperty("Name", out var nameValue) || nameValue.ValueKind != JsonValueKind.String)
                        throw new ArgumentException($"Each JSON {key} entry needs a string Name.");
                    name = nameValue.GetString();
                    if (call.TryGetProperty("Args", out var args))
                        foreach (var argument in args.EnumerateObject()) arguments.Add(argument.Name, argument.Value);
                }
                // Serilog's built-in context enrichment is an instance method, not an extension.
                if (key == "Enrich" && name == "FromLogContext" && arguments.Count == 0)
                {
                    ((Serilog.Configuration.LoggerEnrichmentConfiguration)target).FromLogContext();
                    continue;
                }
                var candidates = new List<(MethodInfo Method, object[] Values)>();
                foreach (var method in methods.Where(m => m.Name == name && m.GetParameters()[0].ParameterType == target.GetType()))
                {
                    var parameters = method.GetParameters();
                    if (arguments.Keys.Any(k => !parameters.Skip(1).Any(p => string.Equals(p.Name, k, StringComparison.OrdinalIgnoreCase)))) continue;
                    var values = new object[parameters.Length];
                    values[0] = target;
                    var valid = true;
                    for (var i = 1; i < parameters.Length; i++)
                    {
                        var parameter = parameters[i];
                        if (arguments.TryGetValue(parameter.Name, out var value))
                        {
                            try
                            {
                                values[i] = ArgumentValue(value, parameter.ParameterType);
                                if (key == "WriteTo" && method.DeclaringType == typeof(FileLoggerConfigurationExtensions) && parameter.Name == "path")
                                    values[i] = ProviderFilePath.Resolve(sessionState, (string)values[i]);
                            }
                            catch (Exception error) when (error is ArgumentException || error is FormatException || error is InvalidOperationException || error is OverflowException)
                            { valid = false; break; }
                        }
                        else if (parameter.HasDefaultValue) values[i] = parameter.DefaultValue;
                        else { valid = false; break; }
                    }
                    if (valid) candidates.Add((method, values));
                }
                if (candidates.Count != 1)
                    throw new ArgumentException($"JSON {key} configuration requires exactly one matching public method with supported arguments. Import the extension first and check method names, argument names and scalar types.");
                try { candidates[0].Method.Invoke(null, candidates[0].Values); }
                catch (TargetInvocationException error) when (error.InnerException != null)
                {
                    // Avoid copying configuration argument values into our error text.
                    throw new ArgumentException($"The JSON {key} configuration method failed. Check its arguments.", error.InnerException);
                }
            }
        }

        private static object ArgumentValue(JsonElement value, Type type)
        {
            var nullable = Nullable.GetUnderlyingType(type);
            if (value.ValueKind == JsonValueKind.Null)
            {
                if (!type.IsValueType || nullable != null) return null;
                throw new ArgumentException("Null is invalid for this value type.");
            }
            type = nullable ?? type;
            if (type == typeof(string)) return value.GetString();
            if (type == typeof(bool)) return value.GetBoolean();
            if (type.IsEnum)
            {
                var name = value.GetString();
                if (name == null || !Enum.GetNames(type).Any(n => string.Equals(n, name, StringComparison.OrdinalIgnoreCase)))
                    throw new ArgumentException("Invalid enum name.");
                return Enum.Parse(type, name, ignoreCase: true);
            }
            if (type == typeof(TimeSpan)) return TimeSpan.Parse(value.GetString(), CultureInfo.InvariantCulture);
            if (type == typeof(Uri)) return new Uri(value.GetString(), UriKind.Absolute);
            if (type.IsPrimitive || type == typeof(decimal)) return JsonSerializer.Deserialize(value.GetRawText(), type);
            throw new ArgumentException("Complex JSON method arguments are unsupported; use the PowerShell pipeline.");
        }

        private static LogEventLevel Level(JsonElement value)
            => (LogEventLevel)ArgumentValue(value, typeof(LogEventLevel));

        private static object PropertyValue(JsonElement value)
            => value.ValueKind switch
            {
                JsonValueKind.Object => value.EnumerateObject().ToDictionary(p => p.Name, p => PropertyValue(p.Value)),
                JsonValueKind.Array => value.EnumerateArray().Select(PropertyValue).ToArray(),
                JsonValueKind.String => value.GetString(),
                JsonValueKind.Number => value.TryGetInt64(out var integer) ? (object)integer : value.GetDouble(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                _ => null
            };

        private static JsonElement.ArrayEnumerator ArrayItems(JsonElement value, string key)
            => value.ValueKind == JsonValueKind.Array ? value.EnumerateArray()
                : throw new ArgumentException($"The JSON {key} section must be an array.");

        private static void ValidateKeys(JsonElement value, params string[] allowed)
        {
            foreach (var property in value.EnumerateObject())
                if (!allowed.Contains(property.Name, StringComparer.Ordinal))
                    throw new ArgumentException("Unsupported JSON configuration key. See the PoShLog JSON configuration guide.");
        }
    }
}
