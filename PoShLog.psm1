[string] $Global:packagesPath = "$PSScriptRoot\packages"
[string] $Global:packagesConfigPath = "$PSScriptRoot\packages.config"

## dot source all script files
Get-ChildItem -Path "$PSScriptRoot\functions" -Recurse -File -Filter '*.ps1' | ForEach-Object {
    . $_.FullName

    if($_.FullName -notcontains 'internal'){
        Export-ModuleMember $_.BaseName
    }
}



