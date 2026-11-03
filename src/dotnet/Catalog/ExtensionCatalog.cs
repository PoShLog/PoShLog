using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation.Language;
using System.Reflection;

namespace PoShLog.Core.Catalog
{
	/// <summary>
	/// The first-party extensions this Core build knows about. The build embeds every extensions/*/*.psd1 and
	/// src/PoShLog.psd1, so the catalogue is the manifests of the same commit and cannot go stale (ADR 0021).
	/// </summary>
	public static class ExtensionCatalog
	{
		internal const string ExtensionResourcePrefix = "PoShLog.Catalog.Extensions.";
		internal const string CoreResource = "PoShLog.Catalog.PoShLog.psd1";

		private static readonly string[] KnownPlatforms = { "Windows", "Linux", "MacOS" };

		private static readonly Lazy<IReadOnlyList<ExtensionEntry>> LazyExtensions = new Lazy<IReadOnlyList<ExtensionEntry>>(LoadExtensions);
		private static readonly Lazy<Hashtable> LazyCore = new Lazy<Hashtable>(() => ReadManifest(ReadResource(CoreResource), CoreResource));

		public static IReadOnlyList<ExtensionEntry> Extensions => LazyExtensions.Value;

		/// <summary>ModuleVersion of the PoShLog manifest this assembly was built with.</summary>
		public static string CoreVersion => LazyCore.Value["ModuleVersion"]?.ToString();

		/// <summary>Prerelease label of that manifest, or an empty string for a stable build.</summary>
		public static string CorePrerelease => GetPrerelease(LazyCore.Value);

		public static bool CoreIsPrerelease => CorePrerelease.Length > 0;

		public static ExtensionEntry Find(string name) =>
			Extensions.FirstOrDefault(e => string.Equals(e.Name, name, StringComparison.OrdinalIgnoreCase));

		private static IReadOnlyList<ExtensionEntry> LoadExtensions()
		{
			var assembly = typeof(ExtensionCatalog).Assembly;
			return assembly.GetManifestResourceNames()
				.Where(r => r.StartsWith(ExtensionResourcePrefix, StringComparison.Ordinal) && r.EndsWith(".psd1", StringComparison.Ordinal))
				.Select(r => FromManifest(r.Substring(ExtensionResourcePrefix.Length, r.Length - ExtensionResourcePrefix.Length - ".psd1".Length), ReadManifest(ReadResource(r), r)))
				.OrderBy(e => e.Name, StringComparer.OrdinalIgnoreCase)
				.ToList();
		}

		private static string ReadResource(string name)
		{
			using var stream = typeof(ExtensionCatalog).Assembly.GetManifestResourceStream(name)
				?? throw new InvalidOperationException($"PoShLog.Core.dll was built without the resource '{name}'.");
			using var reader = new StreamReader(stream);
			return reader.ReadToEnd();
		}

		/// <summary>
		/// Evaluates a module manifest as data only, like Import-PowerShellDataFile: constants, arrays and hashtables, no code.
		/// </summary>
		internal static Hashtable ReadManifest(string text, string source)
		{
			var ast = Parser.ParseInput(text, out _, out var errors);
			if (errors.Length > 0)
			{
				throw new InvalidDataException($"The manifest '{source}' does not parse: {errors[0].Message}");
			}
			if (ast.Find(a => a is HashtableAst, false) is not HashtableAst hashtable)
			{
				throw new InvalidDataException($"The manifest '{source}' has no hashtable.");
			}
			return (Hashtable)hashtable.SafeGetValue();
		}

		internal static ExtensionEntry FromManifest(string name, Hashtable manifest)
		{
			var psData = GetPSData(manifest);
			var prerelease = GetPrerelease(manifest);
			var version = manifest["ModuleVersion"]?.ToString();
			var tags = ToStrings(psData?["Tags"]);
			var commands = ToStrings(manifest["CmdletsToExport"]).Concat(ToStrings(manifest["FunctionsToExport"]))
				.Where(c => !c.Contains('*'))
				.Distinct(StringComparer.OrdinalIgnoreCase)
				.ToArray();
			return new ExtensionEntry
			{
				Name = name,
				Kind = name.Contains(".Sinks.", StringComparison.OrdinalIgnoreCase) ? "Sink" : "Enricher",
				Version = prerelease.Length > 0 ? $"{version}-{prerelease}" : version,
				Summary = GetSummary(manifest["Description"]?.ToString()),
				Commands = commands,
				Platforms = KnownPlatforms.Where(p => tags.Contains(p, StringComparer.OrdinalIgnoreCase)).ToArray(),
				ProjectUri = psData?["ProjectUri"]?.ToString(),
			};
		}

		/// <summary>
		/// The extension manifests describe the module in the second line of Description; the first line says what PoShLog
		/// is, and a blank line ends the summary.
		/// </summary>
		internal static string GetSummary(string description)
		{
			if (string.IsNullOrWhiteSpace(description))
			{
				return string.Empty;
			}
			var lines = description.Replace("\r\n", "\n").Split('\n');
			return string.Join(" ", lines.Skip(1).TakeWhile(l => l.Trim().Length > 0).Select(l => l.Trim()));
		}

		private static Hashtable GetPSData(Hashtable manifest) =>
			(manifest["PrivateData"] as Hashtable)?["PSData"] as Hashtable;

		private static string GetPrerelease(Hashtable manifest) =>
			GetPSData(manifest)?["Prerelease"]?.ToString() ?? string.Empty;

		private static string[] ToStrings(object value) => value switch
		{
			null => Array.Empty<string>(),
			string s => new[] { s },
			IEnumerable items => items.Cast<object>().Where(i => i != null).Select(i => i.ToString()).ToArray(),
			_ => new[] { value.ToString() },
		};
	}
}
