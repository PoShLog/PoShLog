# Core's RequiredModules entry guarantees that shared Serilog assemblies load first.
# Protobuf, gRPC and Microsoft.Extensions.Logging.Abstractions may already be loaded by another module. A loaded copy
# of the same or a newer version is used as it is; Add-Type of a second copy would fail (docs/decisions/0012).
$loaded = @{}
foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
    $loaded[$assembly.GetName().Name] = $assembly.GetName().Version
}
$cmdlets = Join-Path $PSScriptRoot 'lib/PoShLog.Sinks.OpenTelemetry.dll'
Get-ChildItem "$PSScriptRoot/lib" -Filter '*.dll' -File | Where-Object FullName -ne $cmdlets | ForEach-Object {
    $name = [Reflection.AssemblyName]::GetAssemblyName($_.FullName)
    $present = $loaded[$name.Name]
    if (!$present) {
        Add-Type -Path $_.FullName -ErrorAction Stop
    } elseif ($present -lt $name.Version) {
        throw "PoShLog.Sinks.OpenTelemetry needs $($name.Name) $($name.Version), but $present is already loaded by another module. Import PoShLog.Sinks.OpenTelemetry first, or in a new session."
    }
}
Import-Module $cmdlets -ErrorAction Stop
Export-ModuleMember -Cmdlet 'Add-SinkOpenTelemetry'
