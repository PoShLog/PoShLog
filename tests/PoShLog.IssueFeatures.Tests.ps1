#Requires -Version 7.6

BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/..").Path
    $manifest = (Join-Path $root 'src/PoShLog.psd1').Replace("'", "''")
    function Invoke-IssueChild([string]$Body) {
        $child = Join-Path $TestDrive "child-$([guid]::NewGuid()).ps1"
        Set-Content -LiteralPath $child -Value "`$ErrorActionPreference = 'Stop'`nImport-Module '$manifest'`n$Body"
        $output = & (Join-Path $PSHOME 'pwsh') -NoProfile -NonInteractive -File $child 2>&1
        if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
        $output | ForEach-Object { "$_" }
    }
}

Describe 'Issue features in fresh PowerShell processes' {
    It 'hides the merged expression engine from public reflection and PowerShell lookup' {
        $output = Invoke-IssueChild @'
$child = New-Logger | Start-Logger -PassThru
try {
    New-Logger | Add-SinkLogger -Logger $child -Filter 'Send = true' | Start-Logger
} finally { Close-Logger; $child.Dispose() }
$core = (Get-Command Add-SinkLogger).ImplementingType.Assembly
if (@($core.GetExportedTypes() | Where-Object { $_.FullName -like 'Serilog.*' }).Count) { throw 'Merged types are exported.' }
foreach ($name in 'Serilog.Expressions.SerilogExpression', 'Serilog.LoggerSinkConfigurationExtensions') {
    if (($core.GetType($name, $true)).IsVisible) { throw "Merged type is public: $name" }
    if ($name -as [type]) { throw "PowerShell can see $name" }
}
if (@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Serilog.Expressions' }).Count) { throw 'Standalone Expressions loaded.' }
if (Test-Path (Join-Path (Split-Path $core.Location) 'Serilog.Expressions.dll')) { throw 'Standalone Expressions shipped.' }
if (@($core.GetReferencedAssemblies() | Where-Object Name -eq 'Serilog').Count -ne 1) { throw 'Shared Serilog reference missing.' }
"PASS hidden types: GetExportedTypes=0; PowerShell lookup=0; standalone Expressions=0; shared Serilog=1; host=$($PSVersionTable.PSVersion)"
'@
        $output | Should -Contain "PASS hidden types: GetExportedTypes=0; PowerShell lookup=0; standalone Expressions=0; shared Serilog=1; host=$($PSVersionTable.PSVersion)"
    }

    It 'resolves relative File paths against the PowerShell location (#41)' {
        $location = $TestDrive.Replace("'", "''")
        $output = Invoke-IssueChild @"
Set-Location '$location'
New-Logger | Add-SinkFile -Path './relative.log' -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger
Write-InfoLog 'relative path works'
Close-Logger
Get-Content './relative.log'
"@
        $output | Should -Contain 'relative path works'
    }

    It 'routes properties to a conditional child logger (#37)' {
        $location = $TestDrive.Replace("'", "''")
        $output = Invoke-IssueChild @"
Set-Location '$location'
`$child = New-Logger | Add-SinkFile -Path './selected.log' -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger -PassThru
try {
    New-Logger | Add-SinkLogger -Logger `$child -Filter 'Send = true' | Start-Logger
    Write-InfoLog 'selected {Send}' -PropertyValues `$true
    Write-InfoLog 'excluded {Send}' -PropertyValues `$false
} finally { Close-Logger; `$child.Dispose() }
Get-Content './selected.log'
"@
        $output | Should -Contain 'selected true'
        $output | Should -Not -Contain 'excluded false'
    }

    It 'loads JSON and configures a loaded extension enricher (#39)' {
        # extensions/*/lib is build output (gitignored); CI checkouts do not have it.
        if (!(Test-Path "$root/extensions/PoShLog.Enrichers/lib")) {
            & "$root/build/Build-Extension.ps1" -Module PoShLog.Enrichers | Out-Null
        }
        $extension = (Join-Path $root 'extensions/PoShLog.Enrichers/PoShLog.Enrichers.psd1').Replace("'", "''")
        $location = $TestDrive.Replace("'", "''")
        Set-Content (Join-Path $TestDrive 'logging.json') '{"Serilog":{"MinimumLevel":"Warning","Enrich":["WithMachineName","WithProcessId"],"WriteTo":[{"Name":"File","Args":{"path":"./configured.log","outputTemplate":"{MachineName} {ProcessId} {Message:lj}{NewLine}"}}]}}'
        $output = Invoke-IssueChild @"
Import-Module '$extension'
Set-Location '$location'
New-Logger -ConfigurationPath './logging.json' | Start-Logger
Write-InfoLog 'excluded'
Write-WarningLog 'configured'
Close-Logger
`$content = Get-Content './configured.log' -Raw
if (`$content -notmatch ([regex]::Escape([Environment]::MachineName) + ' \d+ configured')) { throw 'Missing extension properties.' }
if (`$content -match 'excluded') { throw 'Minimum level was ignored.' }
'JSON extension configuration works'
"@
        $output | Should -Contain 'JSON extension configuration works'
    }

    It 'colors string and number arguments with ANSI token styles (#30)' {
        $output = Invoke-IssueChild @'
[Environment]::SetEnvironmentVariable('NO_COLOR', $null)
$PSStyle.OutputRendering = 'Ansi'
$theme = New-ConsoleTheme -AnsiStyles @{ String = "`e[32m"; Number = "`e[36m" }
New-Logger | Add-SinkConsole -Theme $theme -ApplyThemeToRedirectedOutput -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger
Write-InfoLog 'User {Name} has {Count} items' -PropertyValues 'Ada', 3
Close-Logger
'@
        ($output -join "`n") | Should -Match ([regex]::Escape("`e[32mAda`e[0m"))
        ($output -join "`n") | Should -Match ([regex]::Escape("`e[36m3`e[0m"))
    }

    It 'configures loaded Seq and Http sinks from JSON and delivers to loopback (#39)' {
        Import-Module "$root/src/PoShLog.psd1" -Force
        foreach ($extensionName in 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.Http') {
            if (!(Test-Path "$root/extensions/$extensionName/lib")) {
                & "$root/build/Build-Extension.ps1" -Module $extensionName | Out-Null
            }
            Import-Module "$root/extensions/$extensionName/$extensionName.psd1"
        }
        if (!('CompatHttpListener' -as [type])) { Add-Type -Path "$root/tests/compat/CompatHttpListener.cs" }
        $seq = [CompatHttpListener]::new()
        $http = [CompatHttpListener]::new()
        try {
            $configuration = @{ Serilog = @{ WriteTo = @(
                @{ Name = 'Seq'; Args = @{ serverUrl = $seq.Url; period = '00:00:00.100' } },
                @{ Name = 'Http'; Args = @{ requestUri = $http.Url; queueLimitBytes = $null; period = '00:00:00.100' } }
            ) } }
            $configuration | ConvertTo-Json -Depth 8 | Set-Content "$TestDrive/network.json"
            New-Logger -ConfigurationPath "$TestDrive/network.json" | Start-Logger
            Write-InfoLog 'JSON network delivery'
            Close-Logger
            $deadline = [datetime]::UtcNow.AddSeconds(10)
            while (($seq.Bodies.IsEmpty -or $http.Bodies.IsEmpty) -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
            ($seq.Bodies.ToArray() -join '') | Should -Match 'JSON network delivery'
            ($http.Bodies.ToArray() -join '') | Should -Match 'JSON network delivery'
        } finally {
            Close-Logger
            $seq.Dispose()
            $http.Dispose()
            Remove-Module PoShLog.Sinks.Seq, PoShLog.Sinks.Http -ErrorAction SilentlyContinue
        }
    }
    It 'preserves legacy sink helper type lookup after compiling expressions (#37)' {
        $output = Invoke-IssueChild @'
$child = New-Logger | Start-Logger -PassThru
try {
    New-Logger | Add-SinkLogger -Logger $child -Filter 'Send = true' | Start-Logger
    Write-InfoLog 'compiled {Send}' -PropertyValues $true
} finally { Close-Logger; $child.Dispose() }
# The published Exceptionless wrapper resolves this unqualified helper type name.
Add-Type 'namespace Serilog { public static class LoggerSinkConfigurationExtensions { public static string LegacyMarker() { return "legacy helper found"; } } }'
[Serilog.LoggerSinkConfigurationExtensions]::LegacyMarker()
'@
        $output | Should -Contain 'legacy helper found'
    }
}
