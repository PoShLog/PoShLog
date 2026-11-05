using System.Management.Automation;
using System.Runtime.Versioning;

[assembly: TargetFramework("__FRAMEWORK__")]

namespace PoShLog.Core
{
    public static class DesktopAssemblyResolver
    {
        public static void Register(string directory) { }
    }
}

[Cmdlet(VerbsDiagnostic.Test, "LoaderFixture")]
[Alias("tlf")]
public sealed class TestLoaderFixtureCommand : PSCmdlet
{
    protected override void ProcessRecord()
    {
        WriteObject("__EDITION__");
    }
}
