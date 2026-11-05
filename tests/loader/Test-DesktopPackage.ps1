#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Manifest,
    [string]$V2Manifest = 'F:/Root/wt/PoShLog-v2/artifacts/PoShLog/PoShLog.psd1',
    [string]$Case,
    [string]$FixtureDirectory,
    [string]$Results = (Join-Path ([IO.Path]::GetTempPath()) ('PoShLog-package-' + [guid]::NewGuid().ToString('N')))
)
$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Condition, [string]$Message) { if (!$Condition) { throw $Message } }
function Assert-NoCore {
    $packageLib = Join-Path (Split-Path $Manifest) 'lib'
    Assert-True (@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
        !$_.IsDynamic -and $_.Location.StartsWith($packageLib, [StringComparison]::OrdinalIgnoreCase)
    }).Count -eq 0) 'Guard loaded a v3 package assembly.'
}
if ($Case) {
    # Never discover or autoload modules installed from the Gallery.
    $env:PSModulePath = Join-Path $PSHOME 'Modules'
    $folder = Join-Path (Split-Path $Manifest) 'lib/net472'
    switch ($Case) {
        'Import' {
            Import-Module $Manifest -ErrorAction Stop
            $data = Import-PowerShellDataFile $Manifest
            $actual = ((Get-Command -Module PoShLog -Name *).Name | Sort-Object) -join ','
            $expected = ($data.CmdletsToExport | Sort-Object) -join ','
            Assert-True ($actual -eq $expected) 'Wrong exports.'
            $target = if ($PSEdition -eq 'Desktop') { 'net472' } else { 'net10.0' }
            $core = (Get-Command New-Logger).ImplementingType.Assembly
            Assert-True ($core.Location -eq (Join-Path (Split-Path $Manifest) "lib/$target/PoShLog.Core.dll")) 'Wrong Core target.'
            Start-Logger -Console
            Write-InfoLog 'staged package ready'
            Close-Logger
            Assert-True (@(Get-PoShLogExtension).Count -gt 0) 'Manifest catalogue failed.'
            Remove-Module PoShLog
            Import-Module $Manifest -ErrorAction Stop
            Assert-True (@(Get-Command -Module PoShLog).Count -eq $data.CmdletsToExport.Count) 'Reimport lost exports.'
        }
        'Bootstrap' {
            $before = @([AppDomain]::CurrentDomain.GetAssemblies().FullName)
            $core = [Reflection.Assembly]::LoadFrom((Join-Path $folder 'PoShLog.Core.dll'))
            $resolver = $core.GetType('PoShLog.Core.DesktopAssemblyResolver', $true)
            $resolver.GetMethod('Register').Invoke($null, [object[]]@([string]$folder)) | Out-Null
            $newDependencies = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
                $_.FullName -notin $before -and $_.GetName().Name -ne 'PoShLog.Core'
            })
            Assert-True ($newDependencies.Count -eq 0) "Bootstrap resolved dependencies too early: $newDependencies"
            Import-Module $Manifest -ErrorAction Stop
            $resolve = $resolver.GetMethod('Resolve', [Reflection.BindingFlags]'NonPublic,Static')
            foreach ($file in Get-ChildItem $folder -Filter '*.dll' | Where-Object { $_.BaseName -eq 'Serilog' -or $_.BaseName -like 'Serilog.Sinks.*' -or $_.BaseName -like 'System.*' }) {
                $identity = [Reflection.AssemblyName]::GetAssemblyName($file.FullName)
                foreach ($version in @($identity.Version, [version]'0.0.0.0')) {
                    $request = [Reflection.AssemblyName]::new($identity.FullName)
                    $request.Version = $version
                    $resolved = $resolve.Invoke($null, @($null, [ResolveEventArgs]::new($request.FullName)))
                    Assert-True ($resolved.Location -eq $file.FullName) "Resolver did not return Core's copy of $request."
                }
                $identity.Version = [version]'99.0.0.0'
                Assert-True ($null -eq $resolve.Invoke($null, @($null, [ResolveEventArgs]::new($identity.FullName)))) 'Resolver answered a higher version.'
            }
            foreach ($request in 'Unowned.Dependency, Version=1.0.0.0', 'Serilog.Expressions, Version=1.0.0.0', 'Microsoft.Bcl.AsyncInterfaces, Version=1.0.0.0', 'System.Management.Automation, Version=1.0.0.0', 'Serilog, Version=1.0.0.0, Culture=fr', 'Serilog, Version=1.0.0.0, PublicKeyToken=0000000000000000') {
                Assert-True ($null -eq $resolve.Invoke($null, @($null, [ResolveEventArgs]::new($request)))) "Resolver answered an unowned identity: $request"
            }
        }
        'ForeignCopy' {
            $foreign = Join-Path $Results 'foreign'
            New-Item $foreign -ItemType Directory -Force | Out-Null
            Copy-Item (Join-Path $folder 'Serilog.dll') $foreign
            $null = [Reflection.Assembly]::LoadFrom((Join-Path $foreign 'Serilog.dll'))
            $core = [Reflection.Assembly]::LoadFrom((Join-Path $folder 'PoShLog.Core.dll'))
            $resolver = $core.GetType('PoShLog.Core.DesktopAssemblyResolver', $true)
            $resolver.GetMethod('Register').Invoke($null, [object[]]@([string]$folder)) | Out-Null
            $resolve = $resolver.GetMethod('Resolve', [Reflection.BindingFlags]'NonPublic,Static')
            $identity = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $folder 'Serilog.dll'))
            $identity.Version = [version]'0.0.0.0'
            Assert-True ($null -eq $resolve.Invoke($null, @($null, [ResolveEventArgs]::new($identity.FullName)))) 'Resolver substituted a foreign copy.'
        }
        { $_ -in 'CoreFirst', 'ExtensionFirst' } {
            # Keep the fixture apart from its old Serilog. It must bind through Core's resolver.
            if ($Case -eq 'CoreFirst') { Import-Module $Manifest -ErrorAction Stop }
            $fixture = [Reflection.Assembly]::LoadFrom((Join-Path $FixtureDirectory 'LegacyExtension.dll'))
            if ($Case -eq 'ExtensionFirst') { Import-Module $Manifest -ErrorAction Stop }
            $file = Join-Path $Results "$Case.log"
            $logger = $fixture.GetType('LegacyExtension').GetMethod('CreateLogger').Invoke($null, [object[]]@([string]$file))
            try { Write-InfoLog 'legacy contract marker' -Logger $logger } finally { $logger.Dispose() }
            Assert-True ((Get-Content $file -Raw) -eq 'legacy contract marker') 'Legacy fixture did not deliver.'
            $serilog = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Serilog' })
            Assert-True ($serilog.Count -eq 1 -and $serilog[0].Location -eq (Join-Path $folder 'Serilog.dll')) 'Legacy fixture used another Serilog.'
        }
        { $_ -in 'V2Guard', 'SerilogGuard' } {
            if ($Case -eq 'V2Guard') { Import-Module $V2Manifest -ErrorAction Stop }
            else { $null = [Reflection.Assembly]::LoadFrom((Join-Path (Split-Path $V2Manifest) 'lib/Serilog.dll')) }
            $failure = $null
            try { Import-Module $Manifest -ErrorAction Continue } catch { $failure = $_ }
            $expected = if ($Case -eq 'V2Guard') { '*PoShLog 2.x is loaded*' } else { '*Serilog*already loaded*' }
            Assert-True ($null -ne $failure -and $failure.ToString() -like $expected) "Guard failure: $failure"
            Assert-NoCore
        }
        default { throw "Unknown case $Case." }
    }
    Write-Output "PASS $PSEdition $($PSVersionTable.PSVersion) real package $Case"
    exit 0
}

Assert-True (Test-Path $V2Manifest) 'Provide the built first-party v2 manifest for real guard tests.'
New-Item $Results -ItemType Directory -Force | Out-Null
$fixtureProject = Join-Path $PSScriptRoot 'fixtures/LegacyExtension/LegacyExtension.csproj'
dotnet build $fixtureProject -c Release --configfile "$PSScriptRoot/../../build/nuget.config"
if ($LASTEXITCODE) { throw 'Legacy fixture build failed.' }
$FixtureDirectory = Join-Path $Results 'fixture'
New-Item $FixtureDirectory -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot/fixtures/LegacyExtension/bin/Release/net472/LegacyExtension.dll" $FixtureDirectory
$Manifest = (Resolve-Path $Manifest).Path
$count = 0
foreach ($hostPath in @((Get-Command powershell.exe).Source, (Get-Command pwsh).Source)) {
    $cases = @('Import')
    if ($hostPath -like '*WindowsPowerShell*') { $cases += 'Bootstrap', 'ForeignCopy', 'CoreFirst', 'ExtensionFirst', 'V2Guard', 'SerilogGuard' }
    foreach ($testCase in $cases) {
        & $hostPath -NoProfile -NonInteractive -File $PSCommandPath -Manifest $Manifest -V2Manifest $V2Manifest -Case $testCase -FixtureDirectory $FixtureDirectory -Results $Results
        if ($LASTEXITCODE) { throw "Real package case $testCase failed in $hostPath." }
        $count++
    }
}
Write-Output "PASS all $count real-package clean-process cases. Results $Results"
