#Requires -Version 7.6
# Child processes keep fake assemblies and extension imports out of the other tests' sessions.

Describe 'Refreshed extension loader: <Module>' -ForEach @(
    @{ Module = 'PoShLog.Sinks.Seq'; Assembly = 'Serilog.Sinks.Seq' }
    @{ Module = 'PoShLog.Sinks.EventLog'; Assembly = 'Serilog.Sinks.EventLog' }
    @{ Module = 'PoShLog.Sinks.Http'; Assembly = 'Serilog.Sinks.Http' }
    @{ Module = 'PoShLog.Enrichers'; Assembly = 'Serilog.Enrichers.Environment' }
) {
    BeforeAll {
        $root = (Resolve-Path "$PSScriptRoot/..").Path
        $directory = Join-Path $root "extensions/$Module"
        if (!(Test-Path (Join-Path $directory "lib/$Assembly.dll"))) {
            & (Join-Path $root 'build/Build-Extension.ps1') -Module $Module | Out-Null
        }
        # Escape paths embedded in child PowerShell scripts, including worktrees with apostrophes.
        $corePath = (Join-Path $root 'src/PoShLog.psd1').Replace("'", "''")
        $modulePath = (Join-Path $directory "$Module.psd1").Replace("'", "''")
    }

    It 'imports cleanly and reuses its loaded assemblies on reimport' {
        $child = @"
`$ErrorActionPreference = 'Stop'
Import-Module '$corePath'
Import-Module '$modulePath'
`$manifest = Import-PowerShellDataFile '$modulePath'
`$expected = `$manifest.FunctionsToExport | Sort-Object
if (`$expected -eq '*') {
    `$expected = Get-ChildItem (Join-Path (Split-Path '$modulePath') 'functions') -Recurse -Filter '*.ps1' -File |
        Where-Object { `$_.Directory.Name -ne 'internal' } | Select-Object -ExpandProperty BaseName | Sort-Object
}
`$expected = @(`$expected) + @(`$manifest.CmdletsToExport) | Where-Object { `$_ -and `$_ -ne '*' } | Sort-Object
`$actual = (Get-Command -Module '$Module').Name | Sort-Object
if (@(Compare-Object `$expected `$actual).Count) { throw 'Unexpected exported commands.' }
if ('$Module' -eq 'PoShLog.Sinks.Http') {
    `$client = Get-ApiKeyHttpClient -ApiKey 'synthetic-audit-placeholder' -ErrorAction Stop
    if (`$client -isnot [Serilog.Sinks.Http.IHttpClient]) { throw 'Authentication helper returned an invalid client.' }
    `$client.Dispose()
}
Import-Module '$modulePath' -Force
`$actual = (Get-Command -Module '$Module').Name | Sort-Object
if (@(Compare-Object `$expected `$actual).Count) { throw 'Unexpected exported commands after reimport.' }
'IMPORTED'
"@
        $output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $child
        $LASTEXITCODE | Should -Be 0
        $output | Should -Be 'IMPORTED'
    }

    It 'refuses an older dependency with the module and both versions in the error' {
        $required = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $directory "lib/$Assembly.dll")).Version
        $child = @"
`$name = [Reflection.AssemblyName]::new('$Assembly')
`$name.Version = [version]'1.0.0.0'
`$null = [Reflection.Emit.AssemblyBuilder]::DefineDynamicAssembly(`$name, 'Run')
Import-Module '$corePath' -ErrorAction Stop
try { Import-Module '$modulePath' -ErrorAction Stop; 'IMPORTED' }
catch { `$_.Exception.Message }
if (Get-Module '$Module') { 'MODULE_STILL_LOADED' }
"@
        $output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $child
        $LASTEXITCODE | Should -Be 0
        $expected = "$Module needs $Assembly $required, but 1.0.0.0 is already loaded by another module. Import $Module first, or in a new session."
        $output | Should -Be $expected
    }
}
