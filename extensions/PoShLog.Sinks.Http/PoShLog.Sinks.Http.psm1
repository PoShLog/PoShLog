# Core's RequiredModules entry guarantees that shared Serilog assemblies load first.
Get-ChildItem "$PSScriptRoot/lib" -Filter '*.dll' -File | ForEach-Object {
    Add-Type -Path $_.FullName -ErrorAction Stop
}
Get-ChildItem "$PSScriptRoot/functions" -Recurse -Filter '*.ps1' -File |
    Where-Object { $_.Directory.Name -ne 'internal' } | ForEach-Object {
        . $_.FullName
        Export-ModuleMember -Function $_.BaseName
    }
