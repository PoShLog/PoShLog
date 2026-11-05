[CmdletBinding()]
param(
    [string] $Case,
    [string] $FixtureRoot
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Assert-NoCoreAssembly {
    $loaded = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'PoShLog.Core' })
    Assert-True ($loaded.Count -eq 0) 'A Core assembly was loaded before rejection.'
}

function Assert-Rejected {
    param([scriptblock] $Action, [string] $Message)
    $failure = $null
    try { & $Action } catch { $failure = $_ }
    Assert-True ($null -ne $failure) 'Expected a terminating error.'
    Assert-True ($failure.ToString() -like "*$Message*") "Unexpected error: $failure"
    Assert-NoCoreAssembly
}

function Assert-Exports {
    # Get-Command without -Name defaults to functions/cmdlets and hides aliases.
    $commands = @(Get-Command -Module PoShLog -Name * | Sort-Object Name)
    Assert-True (($commands.Name -join ',') -eq 'Test-LoaderFixture,tlf') "Unexpected exports: $($commands.Name -join ',')"
    Assert-True ($commands[0].CommandType -eq 'Cmdlet') 'Cmdlet export is missing.'
    Assert-True ($commands[1].CommandType -eq 'Alias') 'Alias export is missing.'
    $module = Get-Module PoShLog
    Assert-True ($module.ExportedFunctions.Count -eq 0 -and $module.ExportedVariables.Count -eq 0) 'Internal functions or variables were exported.'
    Assert-True ((Test-LoaderFixture) -eq $PSEdition) 'Wrong target cmdlet loaded.'
    Assert-True ((tlf) -eq $PSEdition) 'Alias does not invoke the target cmdlet.'
    $assemblies = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'PoShLog.Core' })
    Assert-True ($assemblies.Count -eq 1) 'Expected exactly one Core assembly.'
    $target = if ($PSEdition -eq 'Desktop') { 'net472' } else { 'net10.0' }
    Assert-True ($assemblies[0].Location -eq (Join-Path $FixtureRoot "PoShLog/lib/$target/PoShLog.Core.dll")) 'Wrong assembly location.'
    Assert-True (@(Get-Module -All PoShLog.Core).Count -eq 1) 'Expected one nested binary module.'
}

if ($Case) {
    try {
        # Prevent discovery/autoload of any installed Gallery modules.
        $env:PSModulePath = Join-Path $PSHOME 'Modules'
        $manifest = Join-Path $FixtureRoot 'PoShLog/PoShLog.psd1'
        $loader = Join-Path $FixtureRoot 'PoShLog/PoShLog.psm1'
        switch ($Case) {
            'Build' {
                $target = if ($PSEdition -eq 'Desktop') { 'net472' } else { 'net10.0' }
                $framework = if ($PSEdition -eq 'Desktop') { '.NETFramework,Version=v4.7.2' } else { '.NETCoreApp,Version=v10.0' }
                $folder = Join-Path $FixtureRoot "PoShLog/lib/$target"
                New-Item $folder -ItemType Directory -Force | Out-Null
                $source = (Get-Content "$PSScriptRoot/fixtures/Core.cs" -Raw).Replace('__EDITION__', $PSEdition).Replace('__FRAMEWORK__', $framework)
                if ($PSEdition -eq 'Desktop') {
                    Add-Type -TypeDefinition $source -OutputAssembly "$folder/PoShLog.Core.dll"
                } else {
                    # Add-Type on Core chooses a random assembly identity. Compile
                    # with its bundled Roslyn so guard assertions use the real name.
                    $references = @(
                        Get-ChildItem (Join-Path $PSHOME 'ref') -Filter '*.dll' | ForEach-Object {
                            [Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($_.FullName)
                        }
                        [Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile([System.Management.Automation.PSCmdlet].Assembly.Location)
                    )
                    $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($source)
                    $options = [Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary)
                    $compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create('PoShLog.Core', [Microsoft.CodeAnalysis.SyntaxTree[]]@($tree), [Microsoft.CodeAnalysis.MetadataReference[]]$references, $options)
                    $result = [Microsoft.CodeAnalysis.FileSystemExtensions]::Emit($compilation, "$folder/PoShLog.Core.dll")
                    Assert-True $result.Success "Fixture compilation failed: $($result.Diagnostics -join [Environment]::NewLine)"
                }
                if ($PSEdition -eq 'Desktop') {
                    $serilog = Get-Content "$PSScriptRoot/fixtures/Serilog.cs" -Raw
                    Add-Type -TypeDefinition $serilog.Replace('__VERSION__', '4.0.0.0') -OutputAssembly "$folder/Serilog.dll"
                    $old = Join-Path $FixtureRoot 'old'
                    New-Item $old -ItemType Directory -Force | Out-Null
                    Add-Type -TypeDefinition $serilog.Replace('__VERSION__', '2.0.0.0') -OutputAssembly "$old/Serilog.dll"
                    Copy-Item "$PSScriptRoot/fixtures/OldSerilog.psm1" "$old/OldSerilog.psm1"
                    $timing = Join-Path $FixtureRoot 'timing'
                    New-Item "$timing/hidden" -ItemType Directory -Force | Out-Null
                    Add-Type -Path "$PSScriptRoot/fixtures/TimingDependency.cs" -OutputAssembly "$timing/hidden/TimingDependency.dll"
                    Add-Type -Path "$PSScriptRoot/fixtures/TimingCore.cs" -ReferencedAssemblies @("$timing/hidden/TimingDependency.dll", [System.Management.Automation.PSCmdlet].Assembly.Location) -OutputAssembly "$timing/TimingCore.dll"
                }
            }
            'Parse' {
                $tokens = $null
                $errors = $null
                $null = [System.Management.Automation.Language.Parser]::ParseFile($loader, [ref]$tokens, [ref]$errors)
                Assert-True ($errors.Count -eq 0) "Parser errors: $errors"
                Assert-True (@([IO.File]::ReadAllBytes($loader) | Where-Object { $_ -gt 127 }).Count -eq 0) 'Loader contains non-ASCII bytes.'
            }
            'Import' {
                Import-Module $manifest
                Assert-Exports
            }
            'Reimport' {
                Import-Module $manifest
                Assert-Exports
                Remove-Module PoShLog
                Assert-True (@(Get-Command Test-LoaderFixture,tlf -ErrorAction SilentlyContinue).Count -eq 0) 'Commands survived module removal.'
                Assert-True (@(Get-Module -All PoShLog,PoShLog.Core).Count -eq 0) 'Nested module survived removal.'
                Import-Module $manifest
                Assert-Exports
                Remove-Module PoShLog
                Assert-True (@(Get-Command -Module PoShLog,PoShLog.Core -ListImported -Name *).Count -eq 0) 'Exports survived final removal.'
            }
            'Floors' {
                # Extract only the actual check definitions, without executing import.
                $tokens = $null
                $errors = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($loader, [ref]$tokens, [ref]$errors)
                $checks = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
                Assert-True ($checks.Count -eq 2) 'Expected the two internal floor checks.'
                foreach ($check in $checks) { . ([scriptblock]::Create($check.Extent.Text)) }
                Assert-Rejected { Assert-PoShLogCoreHost ([version]'7.5.99') } 'requires PowerShell 7.6'
                Assert-PoShLogCoreHost ([version]'7.6.0')
                Assert-PoShLogCoreHost ([version]'7.7.0')
                Assert-Rejected { Assert-PoShLogDesktopFramework 461807 } 'requires .NET Framework 4.7.2'
                Assert-Rejected { Assert-PoShLogDesktopFramework 0 } 'requires .NET Framework 4.7.2'
                Assert-PoShLogDesktopFramework 461808
                Assert-PoShLogDesktopFramework 533320
            }
            'V2Guard' {
                Import-Module (Join-Path $FixtureRoot 'v2/PoShLog/PoShLog.psd1')
                # Explicit Continue proves that a caller need not request Stop.
                Assert-Rejected { Import-Module $manifest -ErrorAction Continue } 'PoShLog 2.x is loaded'
                Assert-True (@(Get-Command Test-LoaderFixture,tlf -ErrorAction SilentlyContinue).Count -eq 0) 'Guard leaked exports.'
                Assert-True (@(Get-Module PoShLog | Where-Object { $_.Version.Major -eq 3 }).Count -eq 0) 'Failed v3 import remained loaded.'
            }
            'SerilogGuard' {
                Import-Module (Join-Path $FixtureRoot 'old/OldSerilog.psm1')
                Assert-Rejected { Import-Module $manifest -ErrorAction Continue } 'Serilog 2.0.0.0 is already loaded'
                Assert-True (@(Get-Module PoShLog).Count -eq 0) 'Failed import remained loaded.'
                Assert-True (@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Serilog' }).Count -eq 1) 'Guard loaded the packaged Serilog.'
            }
            'TimingWithoutResolver' {
                $failure = $null
                try { Import-Module "$FixtureRoot/timing/TimingCore.dll" } catch { $failure = $_ }
                Assert-True ($null -ne $failure) 'Import unexpectedly resolved the hidden dependency.'
                Assert-True ($failure.ToString() -like '*TimingDependency*') "Unexpected timing failure: $failure"
            }
            'TimingBeforeImport' {
                $null = [Reflection.Assembly]::LoadFrom("$FixtureRoot/timing/TimingCore.dll")
                Assert-True (@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'TimingDependency' }).Count -eq 0) 'LoadFrom resolved the dependency too early.'
                [TimingBootstrap]::Register("$FixtureRoot/timing/hidden/TimingDependency.dll")
                Import-Module "$FixtureRoot/timing/TimingCore.dll"
                Assert-True ((Test-TimingFixture) -eq 'resolved') 'Bootstrap-before-import failed.'
            }
            default { throw "Unknown case '$Case'." }
        }
        Write-Output "PASS $PSEdition $($PSVersionTable.PSVersion) $Case"
        exit 0
    } catch {
        Write-Output "FAIL $PSEdition $Case $($_.ToString())"
        Write-Output $_.ScriptStackTrace
        exit 1
    }
}

# All binaries and staging files stay outside the repository. Keep them for inspection.
$FixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('PoShLog-loader-' + [guid]::NewGuid().ToString('N'))
New-Item "$FixtureRoot/PoShLog", "$FixtureRoot/v2/PoShLog" -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot/../../src/PoShLog.psm1" "$FixtureRoot/PoShLog/PoShLog.psm1"
@'
@{
    RootModule = 'PoShLog.psm1'
    ModuleVersion = '3.0.0'
    FunctionsToExport = @()
    CmdletsToExport = '*'
    AliasesToExport = '*'
    VariablesToExport = @()
}
'@ | Set-Content "$FixtureRoot/PoShLog/PoShLog.psd1" -Encoding ASCII
Copy-Item "$PSScriptRoot/fixtures/PoShLog2.psm1" "$FixtureRoot/v2/PoShLog/PoShLog.psm1"
"@{ RootModule = 'PoShLog.psm1'; ModuleVersion = '2.3.0' }" | Set-Content "$FixtureRoot/v2/PoShLog/PoShLog.psd1" -Encoding ASCII

Write-Output "Fixtures: $FixtureRoot"
$hosts = @((Get-Command powershell.exe).Source, (Get-Command pwsh).Source)
$count = 0
# Stage BOTH targets before either edition imports the loader.
foreach ($executable in $hosts) {
    & $executable -NoLogo -NoProfile -NonInteractive -File $PSCommandPath -Case Build -FixtureRoot $FixtureRoot
    if ($LASTEXITCODE -ne 0) { throw "Fixture build failed in $executable (exit $LASTEXITCODE)." }
    $count++
}
foreach ($executable in $hosts) {
    $cases = @('Parse', 'Import', 'Reimport', 'Floors')
    if ($executable -eq $hosts[0]) { $cases += @('V2Guard', 'SerilogGuard', 'TimingWithoutResolver', 'TimingBeforeImport') }
    foreach ($testCase in $cases) {
        & $executable -NoLogo -NoProfile -NonInteractive -File $PSCommandPath -Case $testCase -FixtureRoot $FixtureRoot
        if ($LASTEXITCODE -ne 0) { throw "Loader fixture case $testCase failed in $executable (exit $LASTEXITCODE)." }
        $count++
    }
}
Write-Output "PASS all $count clean-process cases."
