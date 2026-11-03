namespace PoShLog.Core.Catalog
{
	/// <summary>
	/// One first-party extension, as Get-PoShLogExtension returns it.
	/// </summary>
	public class ExtensionEntry
	{
		public string Name { get; set; }

		/// <summary>Sink or Enricher.</summary>
		public string Kind { get; set; }

		/// <summary>The version in the repository this Core build was made from, with its prerelease label.</summary>
		public string Version { get; set; }

		public string Summary { get; set; }

		public string[] Commands { get; set; }

		public string[] Platforms { get; set; }

		public string ProjectUri { get; set; }

		/// <summary>The newest version found by Get-Module -ListAvailable, or null when it is not installed.</summary>
		public string InstalledVersion { get; set; }

		/// <summary>The newest version in the repository; set only with -Online.</summary>
		public string LatestVersion { get; set; }

		internal ExtensionEntry Copy() => (ExtensionEntry)MemberwiseClone();
	}
}
