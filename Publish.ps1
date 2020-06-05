$ModuleName = 'PoShLog'
$publishFolder = "$PSScriptRoot\publish\$ModuleName\"

#region PoShLog Core

& "$PSScriptRoot\Publish-PoShLogModule.ps1" -ModuleDirectory "$PSScriptRoot\src" -ModuleName $ModuleName -TargetVersion 2.1.0

# Add readme for published module
Copy-Item "$PSScriptRoot\README.md" -Destination $publishFolder

#endregion PoShLog Core

#region Extensions

& "$PSScriptRoot\Publish-PoShLogModule.ps1" -ModuleDirectory "$PSScriptRoot\..\PoShLog.Enrichers" -TargetVersion 1.0.0 -IsExtensionModule
& "$PSScriptRoot\Publish-PoShLogModule.ps1" -ModuleDirectory "$PSScriptRoot\..\PoShLog.Sinks.Exceptionless" -TargetVersion 1.0.0 -IsExtensionModule

#endregion Extensions

## TODO Run tests