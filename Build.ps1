$libFolder = "$PSScriptRoot\src\lib"

dotnet publish -c Release "$PSScriptRoot\src\PoShLogLibs\PoShLogLibs.csproj" -o $libFolder