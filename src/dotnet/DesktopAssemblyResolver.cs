#if NETFRAMEWORK
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

namespace PoShLog.Core
{
    /// <summary>Registers Desktop binding policy before PowerShell enumerates Core's cmdlet types.</summary>
    public static class DesktopAssemblyResolver
    {
        // This type and its entry point must depend only on inbox Framework assemblies.
        private static readonly object Gate = new object();
        private static Dictionary<string, string> paths;

        public static void Register(string directory)
        {
            var folder = Path.GetFullPath(directory);
            if (!string.Equals(folder, Path.GetDirectoryName(typeof(DesktopAssemblyResolver).Assembly.Location),
                StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("The resolver directory must be Core's Desktop assembly directory.", nameof(directory));

            lock (Gate)
            {
                if (paths != null) return;
                var owned = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (var name in new[] {
                    "Serilog", "Serilog.Sinks.File", "Serilog.Sinks.Console",
                    "System.Buffers", "System.Diagnostics.DiagnosticSource", "System.IO.Pipelines",
                    "System.Memory", "System.Numerics.Vectors", "System.Runtime.CompilerServices.Unsafe",
                    "System.Text.Encodings.Web", "System.Text.Json", "System.Threading.Channels",
                    "System.Threading.Tasks.Extensions", "System.ValueTuple"
                })
                {
                    var path = Path.Combine(folder, name + ".dll");
                    if (File.Exists(path)) owned.Add(name, path);
                }
                paths = owned;
                AppDomain.CurrentDomain.AssemblyResolve += Resolve;
            }
        }

        private static Assembly Resolve(object sender, ResolveEventArgs args)
        {
            var requested = new AssemblyName(args.Name);
            if (!paths.TryGetValue(requested.Name, out var path)) return null;
            var shipped = AssemblyName.GetAssemblyName(path);
            if (requested.Version != null && shipped.Version < requested.Version) return null;
            if (!string.Equals(requested.CultureName ?? "", shipped.CultureName ?? "", StringComparison.OrdinalIgnoreCase)) return null;
            var requestedToken = requested.GetPublicKeyToken();
            var shippedToken = shipped.GetPublicKeyToken();
            if (requestedToken != null && requestedToken.Length > 0 && !SameToken(requestedToken, shippedToken)) return null;

            lock (Gate)
            {
                foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
                    if (!assembly.IsDynamic && string.Equals(assembly.Location, path, StringComparison.OrdinalIgnoreCase))
                        return assembly;
                var loaded = Assembly.LoadFrom(path);
                // LoadFrom may unify to an assembly from another module. Never return that copy.
                return string.Equals(loaded.Location, path, StringComparison.OrdinalIgnoreCase) ? loaded : null;
            }
        }

        private static bool SameToken(byte[] left, byte[] right)
        {
            if (right == null || left.Length != right.Length) return false;
            for (var i = 0; i < left.Length; i++)
                if (left[i] != right[i]) return false;
            return true;
        }
    }
}
#endif
