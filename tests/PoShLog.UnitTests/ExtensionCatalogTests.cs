using System.Collections;
using System.Management.Automation;
using PoShLog.Core.Catalog;

namespace PoShLog.UnitTests;

/// <summary>
/// Covers the extension catalogue built from the embedded manifests, Get-PoShLogExtension and Install-PoShLogExtension
/// (ADR 0021). PSResourceGet is replaced by functions that record their parameters; the real install runs in
/// build/Test-ExtensionInstall.ps1.
/// </summary>
public class ExtensionCatalogTests : PoShLogTestBase
{
    private static readonly string RepositoryRoot = FindRepositoryRoot();
    private readonly string _tempDirectory;
    private readonly string? _modulePath = Environment.GetEnvironmentVariable("PSModulePath");

    public ExtensionCatalogTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        _tempDirectory = Path.Combine(Path.GetTempPath(), "PoShLogTests_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDirectory);
    }

    [Fact]
    public void Catalogue_ListsEveryExtensionDirectory()
    {
        var directories = Directory.GetDirectories(Path.Combine(RepositoryRoot, "extensions"))
            .Where(d => File.Exists(Path.Combine(d, Path.GetFileName(d) + ".psd1")))
            .Select(Path.GetFileName)
            .OrderBy(n => n, StringComparer.OrdinalIgnoreCase);

        Assert.Equal(directories, ExtensionCatalog.Extensions.Select(e => e.Name));
    }

    [Fact]
    public void Catalogue_MatchesTheManifestsOnDisk()
    {
        foreach (var entry in ExtensionCatalog.Extensions)
        {
            var manifest = ImportDataFile(Path.Combine(RepositoryRoot, "extensions", entry.Name, entry.Name + ".psd1"));
            var psData = (Hashtable)((Hashtable)manifest["PrivateData"]!)["PSData"]!;

            Assert.Equal($"{manifest["ModuleVersion"]}-{psData["Prerelease"]}", entry.Version);
            Assert.Equal(psData["ProjectUri"]?.ToString(), entry.ProjectUri);
            Assert.NotEmpty(entry.Commands);
            Assert.NotEmpty(entry.Platforms);
            Assert.False(string.IsNullOrWhiteSpace(entry.Summary), $"{entry.Name} has no summary.");
            Assert.DoesNotContain("extension module for PoShLog", entry.Summary);
            Assert.DoesNotContain("For documentation", entry.Summary);
        }
    }

    [Fact]
    public void Catalogue_ReadsCommandsKindAndPlatforms()
    {
        var seq = ExtensionCatalog.Find("poshlog.sinks.seq");
        var eventLog = ExtensionCatalog.Find("PoShLog.Sinks.EventLog");
        var enrichers = ExtensionCatalog.Find("PoShLog.Enrichers");

        Assert.NotNull(seq);
        Assert.Equal("Sink", seq.Kind);
        Assert.Equal(new[] { "Add-SinkSeq" }, seq.Commands);
        Assert.Equal(new[] { "Windows", "Linux", "MacOS" }, seq.Platforms);
        Assert.Equal("Sends log events to Seq (https://datalust.co/seq).", seq.Summary);
        Assert.Equal(new[] { "Windows" }, eventLog!.Platforms);
        Assert.Equal("Enricher", enrichers!.Kind);
        Assert.Contains("Add-EnrichWithProcessId", enrichers.Commands);
    }

    [Fact]
    public void Catalogue_KnowsTheCoreVersionItWasBuiltWith()
    {
        var manifest = ImportDataFile(Path.Combine(RepositoryRoot, "src", "PoShLog.psd1"));
        var psData = (Hashtable)((Hashtable)manifest["PrivateData"]!)["PSData"]!;

        Assert.Equal(manifest["ModuleVersion"]?.ToString(), ExtensionCatalog.CoreVersion);
        Assert.Equal(psData["Prerelease"]?.ToString() ?? string.Empty, ExtensionCatalog.CorePrerelease);
    }

    [Fact]
    public void GetPoShLogExtension_ListsTheCatalogueWithADefaultView()
    {
        var results = Invoke("Get-PoShLogExtension");

        Assert.Equal(ExtensionCatalog.Extensions.Select(e => e.Name), results.Select(r => r.Properties["Name"].Value));
        var view = results[0].Members["PSStandardMembers"] as PSMemberSet;
        var display = view!.Members["DefaultDisplayPropertySet"] as PSPropertySet;
        Assert.Equal(new[] { "Name", "Kind", "Version", "InstalledVersion", "Commands" }, display!.ReferencedPropertyNames);
    }

    [Fact]
    public void GetPoShLogExtension_FiltersByWildcardAndReportsUnknownNames()
    {
        var results = Invoke("Get-PoShLogExtension -Name '*Seq', '*Elastic*', 'PoShLog.Sinks.Nope'", allowErrors: true);

        Assert.Equal(new[] { "PoShLog.Sinks.Seq", "PoShLog.Sinks.Elastic" }, results.Select(r => r.Properties["Name"].Value));
        Assert.Contains("is not a first-party PoShLog extension", LastException?.Message);
    }

    [Fact]
    public void GetPoShLogExtension_ReportsTheNewestInstalledVersion()
    {
        WriteManifest("a", "PoShLog.Sinks.Seq", "1.0.0", null);
        WriteManifest("a", "PoShLog.Sinks.Seq", "2.0.0", "preview2");
        // The same version as a prerelease and stable can only sit in two module roots.
        WriteManifest("a", "PoShLog.Sinks.Http", "2.0.0", "preview2");
        WriteManifest("b", "PoShLog.Sinks.Http", "2.0.0", null);
        UseModulePath("a", "b");

        var results = Invoke("Get-PoShLogExtension -Name PoShLog.Sinks.Seq, PoShLog.Sinks.Http, PoShLog.Sinks.Syslog.Rfc5424");

        Assert.Equal("2.0.0-preview2", results[0].Properties["InstalledVersion"].Value);
        Assert.Equal("2.0.0", results[1].Properties["InstalledVersion"].Value);
        Assert.Null(results[2].Properties["InstalledVersion"].Value);
    }

    [Fact]
    public void GetPoShLogExtension_Online_AsksTheRepositoryForTheLatestVersion()
    {
        Invoke("""
            function global:Find-PSResource {
                param([string[]]$Name, [string]$Type, [switch]$Prerelease, [string[]]$Repository)
                $global:findCall = $PSBoundParameters
                [pscustomobject]@{ Name = 'PoShLog.Sinks.Seq'; Version = [version]'2.0.0'; Prerelease = 'preview2' }
                [pscustomobject]@{ Name = 'PoShLog.Sinks.Seq'; Version = [version]'2.1.0'; Prerelease = 'preview3' }
            }
            """);

        var results = Invoke("Get-PoShLogExtension -Name PoShLog.Sinks.Seq, PoShLog.Sinks.Elastic -Online -Repository Local");

        Assert.Equal("2.1.0-preview3", results[0].Properties["LatestVersion"].Value);
        Assert.Null(results[1].Properties["LatestVersion"].Value);
        var call = (IDictionary)Invoke("$global:findCall")[0].BaseObject;
        Assert.Equal(new[] { "PoShLog.Sinks.Seq", "PoShLog.Sinks.Elastic" }, (string[])call["Name"]!);
        Assert.Equal(new[] { "Local" }, (string[])call["Repository"]!);
        Assert.Equal("Module", call["Type"]);
        Assert.Equal(ExtensionCatalog.CoreIsPrerelease, call.Contains("Prerelease"));
        var display = (PSPropertySet)((PSMemberSet)results[0].Members["PSStandardMembers"]).Members["DefaultDisplayPropertySet"];
        Assert.Contains("LatestVersion", display.ReferencedPropertyNames);
    }

    [Fact]
    public void InstallPoShLogExtension_CallsInstallPSResourceWithThePreviewRule()
    {
        MockInstall();

        Invoke("Install-PoShLogExtension -Name poshlog.sinks.seq -Scope AllUsers -Repository Local -TrustRepository -Confirm:$false");

        var call = SingleInstallCall();
        Assert.Equal("PoShLog.Sinks.Seq", call["Name"]);
        Assert.Equal("AllUsers", call["Scope"]);
        Assert.Equal(new[] { "Local" }, (string[])call["Repository"]!);
        Assert.True(call.Contains("TrustRepository"));
        Assert.False(call.Contains("PassThru"));
        Assert.Equal(ExtensionCatalog.CoreIsPrerelease, call.Contains("Prerelease"));
    }

    [Fact]
    public void InstallPoShLogExtension_PassesPrereleaseWhenAsked()
    {
        MockInstall();

        Invoke("Install-PoShLogExtension PoShLog.Sinks.Seq -Prerelease");

        Assert.True(SingleInstallCall().Contains("Prerelease"));
    }

    [Fact]
    public void InstallPoShLogExtension_WhatIf_InstallsNothing()
    {
        MockInstall();

        Invoke("Install-PoShLogExtension PoShLog.Sinks.Seq -WhatIf");

        Assert.Empty(InstallCalls());
    }

    [Fact]
    public void InstallPoShLogExtension_RejectsNamesOutsideTheCatalogue()
    {
        MockInstall();

        Invoke("Install-PoShLogExtension PoShLog.Sinks.Splunk, PoShLog.Sinks.Seq", allowErrors: true);

        Assert.Contains("'PoShLog.Sinks.Splunk' is not a first-party PoShLog extension", LastException?.Message);
        Assert.Equal("PoShLog.Sinks.Seq", SingleInstallCall()["Name"]);
    }

    [Fact]
    public void InstallPoShLogExtension_TakesNamesFromGetPoShLogExtension()
    {
        MockInstall();

        Invoke("Get-PoShLogExtension '*Seq', '*Http' | Install-PoShLogExtension -PassThru");

        var calls = InstallCalls();
        Assert.Equal(new[] { "PoShLog.Sinks.Seq", "PoShLog.Sinks.Http" }, calls.Select(c => c["Name"]));
        Assert.All(calls, c => Assert.True(c.Contains("PassThru")));
    }

    [Fact]
    public void InstallPoShLogExtension_PassesInstallErrorsAndOutputOn()
    {
        Invoke("""
            function global:Install-PSResource {
                param([string]$Name, [switch]$Prerelease, [switch]$PassThru)
                Write-Error "Package '$Name' could not be installed."
                if ($PassThru) { [pscustomobject]@{ Name = $Name } }
            }
            """);

        var results = Invoke("Install-PoShLogExtension PoShLog.Sinks.Seq -PassThru", allowErrors: true);

        Assert.Equal("Package 'PoShLog.Sinks.Seq' could not be installed.", LastException?.Message);
        Assert.Equal("PoShLog.Sinks.Seq", results.Single().Properties["Name"].Value);
    }

    [Fact]
    public void InstallPoShLogExtension_WarnsAboutAnotherPlatform()
    {
        MockInstall();

        Invoke("Install-PoShLogExtension PoShLog.Sinks.EventLog");

        var warned = Shell.Streams.Warning.Any(w => w.Message.Contains("supports Windows only"));
        Assert.Equal(!OperatingSystem.IsWindows(), warned);
        Assert.Single(InstallCalls());
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        // PSModulePath is a process variable; UseModulePath changes it for the other tests too.
        Environment.SetEnvironmentVariable("PSModulePath", _modulePath);
        if (disposing && Directory.Exists(_tempDirectory))
        {
            Directory.Delete(_tempDirectory, recursive: true);
        }
    }

    private void MockInstall() => Invoke("""
        $global:installCalls = [System.Collections.Generic.List[object]]::new()
        function global:Install-PSResource {
            param([string]$Name, [switch]$Prerelease, [string]$Scope, [string[]]$Repository, [switch]$TrustRepository, [switch]$PassThru)
            $global:installCalls.Add($PSBoundParameters)
        }
        """);

    private List<IDictionary> InstallCalls() =>
        Invoke("$global:installCalls").Select(r => (IDictionary)r.BaseObject).ToList();

    private IDictionary SingleInstallCall() => Assert.Single(InstallCalls());

    /// <summary>Writes a module manifest the way PSResourceGet installs it: the version folder has no prerelease label.</summary>
    private void WriteManifest(string root, string name, string version, string? prerelease)
    {
        var folder = Path.Combine(_tempDirectory, root, name, version);
        Directory.CreateDirectory(folder);
        var label = prerelease is null ? string.Empty : $"Prerelease = '{prerelease}'";
        File.WriteAllText(Path.Combine(folder, name + ".psd1"),
            $"@{{ ModuleVersion = '{version}'; GUID = '{Guid.NewGuid()}'; PrivateData = @{{ PSData = @{{ {label} }} }} }}");
    }

    private void UseModulePath(params string[] roots)
    {
        var path = string.Join(Path.PathSeparator, roots.Select(r => Path.Combine(_tempDirectory, r)));
        Invoke($"$env:PSModulePath = '{path.Replace("'", "''")}'");
    }

    private Hashtable ImportDataFile(string path) =>
        (Hashtable)Invoke($"Import-PowerShellDataFile -LiteralPath '{path.Replace("'", "''")}'")[0].BaseObject;

    private static string FindRepositoryRoot()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory != null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "PoShLog.sln")))
            {
                return directory.FullName;
            }
        }
        throw new InvalidOperationException("The tests must run from a build inside the repository.");
    }
}
