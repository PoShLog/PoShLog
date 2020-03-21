$libFolder = "$PSScriptRoot\src\lib"

# Builds all libraries that PoShLog depends on
dotnet publish -c Release "$PSScriptRoot\src\PoShLogLibs\PoShLogLibs.csproj" -o $libFolder