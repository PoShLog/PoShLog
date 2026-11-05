using System;
using System.IO;
using System.Reflection;
using System.Management.Automation;

// This is a fixture-only resolver, not a proposed production resolver API.
public static class TimingBootstrap
{
    public static void Register(string dependencyPath)
    {
        AppDomain.CurrentDomain.AssemblyResolve += delegate(object sender, ResolveEventArgs args)
        {
            if (new AssemblyName(args.Name).Name == "TimingDependency")
                return Assembly.LoadFrom(dependencyPath);
            return null;
        };
    }
}

[Cmdlet(VerbsDiagnostic.Test, "TimingFixture")]
public sealed class TestTimingFixtureCommand : TimingCommandBase
{
    protected override void ProcessRecord() { WriteObject("resolved"); }
}
