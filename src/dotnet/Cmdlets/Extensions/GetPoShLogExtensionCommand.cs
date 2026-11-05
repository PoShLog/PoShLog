using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using PoShLog.Core.Catalog;

namespace PoShLog.Core.Cmdlets.Extensions
{
	/// <summary>
	/// Lists the first-party PoShLog extensions with their commands and the installed version. -Online adds the latest
	/// version in the repository (ADR 0021).
	/// </summary>
	[Cmdlet(VerbsCommon.Get, "PoShLogExtension", HelpUri = "https://github.com/PoShLog/PoShLog/blob/master/docs/cmdlets/Get-PoShLogExtension.md")]
	[OutputType(typeof(ExtensionEntry))]
	public class GetPoShLogExtensionCommand : PSCmdlet
	{
		private static readonly string[] DefaultProperties = { "Name", "Kind", "Version", "InstalledVersion", "CompatiblePSEditions", "Commands" };

		[Parameter(Position = 0, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, HelpMessage = "Extension names; wildcards are allowed.")]
		[ArgumentCompleter(typeof(ExtensionNameCompleter))]
		[SupportsWildcards]
		public string[] Name { get; set; }

		[Parameter(HelpMessage = "Also looks up the latest version in the repository with Find-PSResource.")]
		public SwitchParameter Online { get; set; }

		[Parameter(HelpMessage = "The PSResourceGet repository -Online searches; by default all registered repositories.")]
		public string[] Repository { get; set; }

		private readonly List<ExtensionEntry> _selected = new List<ExtensionEntry>();

		protected override void ProcessRecord()
		{
			if (Name == null || Name.Length == 0)
			{
				Select(ExtensionCatalog.Extensions);
				return;
			}
			foreach (var name in Name)
			{
				var pattern = WildcardPattern.Get(name, WildcardOptions.IgnoreCase);
				var matches = ExtensionCatalog.Extensions.Where(e => pattern.IsMatch(e.Name)).ToList();
				if (matches.Count == 0 && !WildcardPattern.ContainsWildcardCharacters(name))
				{
					WriteError(ExtensionCommandHelper.UnknownExtension(name));
				}
				Select(matches);
			}
		}

		protected override void EndProcessing()
		{
			if (_selected.Count == 0)
			{
				return;
			}
			var entries = _selected.Select(e => e.Copy()).ToList();
			var names = entries.Select(e => e.Name).ToArray();
			SetInstalledVersions(entries, names);
			if (Online)
			{
				SetLatestVersions(entries, names);
			}
			var properties = Online ? DefaultProperties.Append("LatestVersion").ToArray() : DefaultProperties;
			foreach (var entry in entries)
			{
				var result = PSObject.AsPSObject(entry);
				result.Members.Add(new PSMemberSet("PSStandardMembers", new PSMemberInfo[] { new PSPropertySet("DefaultDisplayPropertySet", properties) }));
				WriteObject(result);
			}
		}

		private void Select(IEnumerable<ExtensionEntry> entries)
		{
			foreach (var entry in entries)
			{
				if (!_selected.Contains(entry))
				{
					_selected.Add(entry);
				}
			}
		}

		private void SetInstalledVersions(List<ExtensionEntry> entries, string[] names)
		{
			var modules = ExtensionCommandHelper.Run(this, "Get-Module", new Hashtable { ["ListAvailable"] = true, ["Name"] = names }, out _)
				.Select(o => o.BaseObject)
				.OfType<PSModuleInfo>()
				.ToList();
			foreach (var entry in entries)
			{
				var newest = modules
					.Where(m => string.Equals(m.Name, entry.Name, StringComparison.OrdinalIgnoreCase))
					.OrderByDescending(m => m.Version)
					// A stable version sorts above its own prereleases.
					.ThenBy(m => string.IsNullOrEmpty(ExtensionCommandHelper.GetPrerelease(m)) ? 0 : 1)
					.ThenByDescending(m => ExtensionCommandHelper.GetPrerelease(m), StringComparer.OrdinalIgnoreCase)
					.FirstOrDefault();
				entry.InstalledVersion = newest == null ? null : ExtensionCommandHelper.FormatVersion(newest.Version, ExtensionCommandHelper.GetPrerelease(newest));
			}
		}

		private void SetLatestVersions(List<ExtensionEntry> entries, string[] names)
		{
			ExtensionCommandHelper.RequireCommand(this, "Find-PSResource");
			var parameters = new Hashtable { ["Name"] = names, ["Type"] = "Module" };
			if (ExtensionCatalog.CoreIsPrerelease)
			{
				parameters["Prerelease"] = true;
			}
			if (Repository != null)
			{
				parameters["Repository"] = Repository;
			}
			var found = ExtensionCommandHelper.Run(this, "Find-PSResource", parameters, out var errors);
			foreach (var error in errors)
			{
				// A name that is not published yet is not an error of this command.
				WriteWarning(error.ToString());
			}
			foreach (var entry in entries)
			{
				var latest = found
					.Where(r => string.Equals(r.Properties["Name"]?.Value?.ToString(), entry.Name, StringComparison.OrdinalIgnoreCase))
					.OrderByDescending(r => r.Properties["Version"]?.Value as Version)
					.FirstOrDefault();
				entry.LatestVersion = latest == null ? null : ExtensionCommandHelper.FormatVersion(latest.Properties["Version"]?.Value, latest.Properties["Prerelease"]?.Value?.ToString());
			}
		}
	}
}
