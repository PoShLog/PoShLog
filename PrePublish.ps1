$ModuleName = 'PoShLog'
$publishFolder = "$PSScriptRoot\publish\$ModuleName\"

& "$PSScriptRoot\PrePublish-PoShLogModule.ps1" -ModuleDirectory "$PSScriptRoot\src" -ProjectPath "$PSScriptRoot\src\dotnet\PoShLog.Core.csproj" -ModuleName $ModuleName -TargetVersion 2.1.0

# Add readme for published module
Copy-Item "$PSScriptRoot\README.md" -Destination $publishFolder

# Run tests
Invoke-Pester -Path "$PSScriptRoot\tests\PoShLog.Tests.ps1"

