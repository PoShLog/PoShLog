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
            return Path.IsPathFullyQualified(path) ? path : resolved;
        }
    }
}
