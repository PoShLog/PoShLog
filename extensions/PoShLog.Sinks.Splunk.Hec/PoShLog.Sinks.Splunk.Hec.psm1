# Core's RequiredModules entry guarantees that shared Serilog assemblies load first.
# Serilog.Sinks.Splunk may already be loaded by another module (the third-party PoShLog.Sinks.Splunk ships 3.7.0). A
# loaded copy of the same or a newer version is used as it is; Add-Type of a second copy would fail (ADR 0012, 0013).
$loaded = @{}
foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
    $loaded[$assembly.GetName().Name] = $assembly.GetName().Version
}
$cmdlets = Join-Path $PSScriptRoot 'lib/PoShLog.Sinks.Splunk.Hec.dll'
# A foreach statement, not ForEach-Object: a throw inside a pipeline in a module script does not stop the import.
foreach ($file in Get-ChildItem "$PSScriptRoot/lib" -Filter '*.dll' -File | Where-Object FullName -ne $cmdlets) {
    $name = [Reflection.AssemblyName]::GetAssemblyName($file.FullName)
    $present = $loaded[$name.Name]
    if (!$present) {
        Add-Type -Path $file.FullName -ErrorAction Stop
    } elseif ($present -lt $name.Version) {
        throw "PoShLog.Sinks.Splunk.Hec needs $($name.Name) $($name.Version), but $present is already loaded by another module (the third-party PoShLog.Sinks.Splunk?). Import PoShLog.Sinks.Splunk.Hec in a new session."
    }
}
Import-Module $cmdlets -ErrorAction Stop
Export-ModuleMember -Cmdlet 'Add-SinkSplunk'
