using System;
using System.Collections;
using System.Linq;
using System.Management.Automation;
using System.Runtime.InteropServices;
using PoShLog.Core.Catalog;

namespace PoShLog.Core.Cmdlets.Extensions
{
	/// <summary>
	/// Installs first-party PoShLog extensions with Install-PSResource. While this Core build is a prerelease, it installs
	/// the prerelease extensions (ADRs 0019 and 0021).
	/// </summary>
	[Cmdlet(VerbsLifecycle.Install, "PoShLogExtension", SupportsShouldProcess = true, ConfirmImpact = ConfirmImpact.Medium,
		HelpUri = "https://github.com/PoShLog/PoShLog/blob/master/docs/cmdlets/Install-PoShLogExtension.md")]
	[OutputType(typeof(PSObject))]
	public class InstallPoShLogExtensionCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, Position = 0, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, HelpMessage = "Extension names, for example PoShLog.Sinks.Seq.")]
		[ArgumentCompleter(typeof(ExtensionNameCompleter))]
		public string[] Name { get; set; }

		[Parameter(HelpMessage = "CurrentUser (default of Install-PSResource) or AllUsers.")]
		[ValidateSet("CurrentUser", "AllUsers")]
		public string Scope { get; set; }

		[Parameter(HelpMessage = "The PSResourceGet repository to install from; by default the registered repositories by priority.")]
		public string[] Repository { get; set; }

		[Parameter(HelpMessage = "Installs prerelease versions also when this PoShLog build is stable.")]
		public SwitchParameter Prerelease { get; set; }

		[Parameter(HelpMessage = "Installs without asking whether to trust the repository; needed in non-interactive sessions for an untrusted repository such as the default PSGallery.")]
		public SwitchParameter TrustRepository { get; set; }

		[Parameter(HelpMessage = "Returns the installed resources.")]
		public SwitchParameter PassThru { get; set; }

		protected override void BeginProcessing()
		{
			ExtensionCommandHelper.RequireCommand(this, "Install-PSResource");
		}

		protected override void ProcessRecord()
		{
			foreach (var name in Name)
			{
				var entry = ExtensionCatalog.Find(name);
				if (entry == null)
				{
					WriteError(ExtensionCommandHelper.UnknownExtension(name));
					continue;
				}
				Install(entry);
			}
		}

		private void Install(ExtensionEntry entry)
		{
			var prerelease = Prerelease || ExtensionCatalog.CoreIsPrerelease;
			if (entry.Platforms.Length > 0 && !entry.Platforms.Any(IsCurrentPlatform))
			{
				WriteWarning($"{entry.Name} supports {string.Join(", ", entry.Platforms)} only; it may not import on this system.");
			}
			var action = prerelease ? "Install-PSResource -Prerelease" : "Install-PSResource";
			if (!ShouldProcess(entry.Name, action))
			{
				return;
			}
			var parameters = new Hashtable { ["Name"] = entry.Name };
			if (prerelease)
			{
				parameters["Prerelease"] = true;
			}
			if (Scope != null)
			{
				parameters["Scope"] = Scope;
			}
			if (Repository != null)
			{
				parameters["Repository"] = Repository;
			}
			if (TrustRepository)
			{
				parameters["TrustRepository"] = true;
			}
			if (PassThru)
			{
				parameters["PassThru"] = true;
			}
			var output = ExtensionCommandHelper.Run(this, "Install-PSResource", parameters, out var errors);
			foreach (var error in errors)
			{
				WriteError(error);
			}
			WriteObject(output, enumerateCollection: true);
		}

		private static bool IsCurrentPlatform(string platform) => platform.ToUpperInvariant() switch
		{
			"WINDOWS" => RuntimeInformation.IsOSPlatform(OSPlatform.Windows),
			"LINUX" => RuntimeInformation.IsOSPlatform(OSPlatform.Linux),
			"MACOS" => RuntimeInformation.IsOSPlatform(OSPlatform.OSX),
			_ => false,
		};
	}
}
