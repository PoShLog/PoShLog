using System;
using System.IO;
using System.Management.Automation;

namespace PoShLog.Core.Utils
{
    internal static class ProviderFilePath
    {
        internal static string Resolve(SessionState sessionState, string path)
        {
            var resolved = sessionState.Path.GetUnresolvedProviderPathFromPSPath(path, out var provider, out _);
            if (provider.ImplementingType != typeof(Microsoft.PowerShell.Commands.FileSystemProvider))
                throw new ArgumentException("The path must use the FileSystem provider.", nameof(path));

            // Preserve native absolute paths; resolve PSDrives and provider-qualified paths via PowerShell.
#if NETFRAMEWORK
            // Framework runs on Windows. Rooted drive-relative paths (C:log and \log) are not absolute.
            var absolute = path.Length >= 3 && char.IsLetter(path[0]) && path[1] == ':' &&
                (path[2] == '\\' || path[2] == '/');
            var unc = path.Length >= 2 && (path[0] == '\\' || path[0] == '/') &&
                (path[1] == '\\' || path[1] == '/');
            return absolute || unc ? path : resolved;
#else
            return Path.IsPathFullyQualified(path) ? path : resolved;
#endif
        }
    }
}
