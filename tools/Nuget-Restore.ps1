# Restore nuget packages from packages.config
nuget install -ConfigFile "$PSScriptRoot\..\NuGet.config" -OutputDirectory "$PSScriptRoot\..\packages"