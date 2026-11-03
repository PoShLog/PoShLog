#Requires -Version 7.4
BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/..").Path
    Import-Module "$root/src/PoShLog.psd1" -ErrorAction Stop
    foreach ($name in 'Http', 'Seq', 'EventLog') {
        & "$root/build/Build-Extension.ps1" -Module "PoShLog.Sinks.$name" | Out-Null
    }
}

Describe 'HTTP and Seq pipeline configuration' {
    It 'configures both independent inputs for <Name>' -ForEach @(
        @{ Name = 'Http'; Command = 'Add-SinkHttp'; Parameter = 'RequestUri' }
        @{ Name = 'Seq'; Command = 'Add-SinkSeq'; Parameter = 'ServerUrl' }
    ) {
        # A child keeps extension dependency versions out of other suites.
        $child = @"
`$ErrorActionPreference = 'Stop'
Import-Module '$root/src/PoShLog.psd1'
Import-Module '$root/extensions/PoShLog.Sinks.$Name/PoShLog.Sinks.$Name.psd1'
Add-Type -Path '$root/tests/compat/CompatHttpListener.cs'
`$listener = [CompatHttpListener]::new()
`$first = New-Logger
`$second = New-Logger
`$options = @{ '$Parameter' = `$listener.Url; Period = [timespan]::FromMilliseconds(50); RestrictedToMinimumLevel = 'Fatal' }
`$output = @(`$first, `$second | $Command @options)
if (`$output.Count -ne 2) { throw "Expected two outputs, got `$(`$output.Count)." }
if (![object]::ReferenceEquals(`$first, `$output[0]) -or ![object]::ReferenceEquals(`$second, `$output[1])) { throw 'Inputs were not preserved.' }
`$index = 0
try { foreach (`$config in `$output) {
    `$logger = `$config.CreateLogger()
    try { `$logger.Fatal("pipeline-marker-`$index"); `$index++ }
    finally { `$logger.Dispose() }
}
`$body = `$listener.Bodies.ToArray() -join "`n"
foreach (`$index in 0..1) { if (!`$body.Contains("pipeline-marker-`$index")) { throw "Missing event from input `$index." } }
} finally { `$listener.Dispose() }
'PIPELINE_OK'
"@
        $output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $child
        $LASTEXITCODE | Should -Be 0
        $output | Should -Be 'PIPELINE_OK'
    }
}

Describe 'EventLog source management binding and safeguard' {
    BeforeAll {
        Import-Module "$root/extensions/PoShLog.Sinks.EventLog/PoShLog.Sinks.EventLog.psd1"
        # Replace only the static sink boundary in an isolated copy of the real function.
        # No test may create an operating-system event source or require administrator rights.
        Add-Type @'
public static class EventLogAuditBoundary {
    public static int Calls;
    public static bool Manage;
    public static object Config;
    public static object EventLog(object writeTo, string source, string log, string machine,
        bool manage, string template, System.IFormatProvider provider, object level, object eventId) {
        Calls++;
        Manage = manage;
        return Config;
    }
}
'@
        $definition = (Get-Content "$root/extensions/PoShLog.Sinks.EventLog/functions/sinks/Add-SinkEventLog.ps1" -Raw).
            Replace('[Serilog.LoggerConfigurationEventLogExtensions]', '[EventLogAuditBoundary]')
        . ([scriptblock]::Create($definition))
    }

    It 'passes a boolean for <Label>' -ForEach @(
        @{ Label = 'omitted'; Options = @{}; Expected = $false }
        @{ Label = 'explicit false'; Options = @{ ManageEventSource = $false }; Expected = $false }
        @{ Label = 'explicit true'; Options = @{ ManageEventSource = $true }; Expected = $true }
    ) {
        [EventLogAuditBoundary]::Calls = 0
        [EventLogAuditBoundary]::Config = New-Logger
        $ConfirmPreference = 'None'
        $config = New-Logger | Add-SinkEventLog -Source 'SyntheticAuditSource' @Options
        [EventLogAuditBoundary]::Calls | Should -Be 1
        [EventLogAuditBoundary]::Manage | Should -Be $Expected
        $config | Should -BeOfType ([Serilog.LoggerConfiguration])
    }

    It 'does not invoke the sink when source management is declined with WhatIf' {
        [EventLogAuditBoundary]::Calls = 0
        $inputConfig = New-Logger
        $result = $inputConfig | Add-SinkEventLog -Source 'SyntheticAuditSource' -ManageEventSource $true -WhatIf
        [EventLogAuditBoundary]::Calls | Should -Be 0
        [object]::ReferenceEquals($inputConfig, $result) | Should -BeTrue
    }

    AfterAll { Remove-Module PoShLog.Sinks.EventLog -ErrorAction SilentlyContinue }
}
