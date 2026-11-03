# Core's RequiredModules entry guarantees that shared Serilog assemblies load first.
# Dependencies may already be loaded by another module. A loaded copy of the same or a newer version is used
# as it is; Add-Type of a second copy would fail (docs/decisions/0012).
$loaded = @{}
foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
    $loaded[$assembly.GetName().Name] = $assembly.GetName().Version
}
# A foreach statement, not ForEach-Object: a throw inside a pipeline in a module script does not stop the import.
foreach ($file in Get-ChildItem "$PSScriptRoot/lib" -Filter '*.dll' -File) {
    $name = [Reflection.AssemblyName]::GetAssemblyName($file.FullName)
    $present = $loaded[$name.Name]
    if (!$present) {
        Add-Type -Path $file.FullName -ErrorAction Stop
    } elseif ($present -lt $name.Version) {
        throw "PoShLog.Sinks.Seq needs $($name.Name) $($name.Version), but $present is already loaded by another module. Import PoShLog.Sinks.Seq first, or in a new session."
    }
}
Get-ChildItem "$PSScriptRoot/functions" -Recurse -Filter '*.ps1' -File |
    Where-Object { $_.Directory.Name -ne 'internal' } | ForEach-Object {
        . $_.FullName
        Export-ModuleMember -Function $_.BaseName
    }
