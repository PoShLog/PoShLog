# Core's RequiredModules entry guarantees that shared Serilog assemblies load first.
# The Elastic assemblies may already be loaded by another module. Elastic.Channels, Elastic.Ingest.* and Elastic.Transport
# carry assembly version 0.0.0.0, so the file version tells their releases apart. A loaded copy of the same or a newer
# version is used as it is; Add-Type of a second copy would fail (ADR 0012, 0015).
function Get-PoShLogFileVersion([string]$Path) {
    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion
    if ($version) { [version]$version } else { [version]'0.0' }
}
$loaded = @{}
foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
    $loaded[$assembly.GetName().Name] = $assembly
}
$cmdlets = Join-Path $PSScriptRoot 'lib/PoShLog.Sinks.Elastic.dll'
# A foreach statement, not ForEach-Object: a throw inside a pipeline in a module script does not stop the import.
foreach ($file in Get-ChildItem "$PSScriptRoot/lib" -Filter '*.dll' -File | Where-Object FullName -ne $cmdlets) {
    $name = [Reflection.AssemblyName]::GetAssemblyName($file.FullName)
    $present = $loaded[$name.Name]
    if (!$present) {
        Add-Type -Path $file.FullName -ErrorAction Stop
        continue
    }
    $presentVersion = $present.GetName().Version
    if ($presentVersion -eq $name.Version -and $present.Location) {
        $presentVersion = Get-PoShLogFileVersion $present.Location
        $needed = Get-PoShLogFileVersion $file.FullName
    } else {
        $needed = $name.Version
    }
    if ($presentVersion -lt $needed) {
        throw "PoShLog.Sinks.Elastic needs $($name.Name) $needed, but $presentVersion is already loaded by another module. Import PoShLog.Sinks.Elastic in a new session."
    }
}
Import-Module $cmdlets -ErrorAction Stop
Export-ModuleMember -Cmdlet 'Add-SinkElasticsearch'
