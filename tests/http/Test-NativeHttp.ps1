#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Stage,
    [Parameter(Mandatory)][ValidateSet('CoreFirst','ExtensionFirst')][string]$Order,
    [Parameter(Mandatory)][string]$Scenario
)
$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Value, [string]$Message) { if (!$Value) { throw $Message } }
function Wait-Until([scriptblock]$Condition, [string]$Message) {
    $deadline = [datetime]::UtcNow.AddSeconds(15)
    while (!(& $Condition)) {
        if ([datetime]::UtcNow -gt $deadline) { throw $Message }
        Start-Sleep -Milliseconds 20
    }
}
# This process can discover only our staged modules and inbox modules.
$env:PSModulePath = $Stage + [IO.Path]::PathSeparator + (Join-Path $PSHOME 'Modules')
$core = Join-Path $Stage 'PoShLog/PoShLog.psd1'
$extension = Join-Path $Stage 'PoShLog.Sinks.Http/PoShLog.Sinks.Http.psd1'
if ($Order -eq 'CoreFirst') {
    Import-Module $core -ErrorAction Stop
    Import-Module $extension -ErrorAction Stop
} else {
    Import-Module $extension -ErrorAction Stop
    Import-Module $core -Force -ErrorAction Stop
}
$target = if ($PSEdition -eq 'Desktop') { 'net472' } else { 'net10.0' }
$null = [Reflection.Assembly]::LoadFrom("$PSScriptRoot/bin/Release/$target/PoShLog.Http.TestFixtures.dll")
$serilog = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Serilog' })
Assert-True ($serilog.Count -eq 1) 'More than one Serilog identity is loaded.'
Assert-True ($serilog[0].GetName().Version -eq [version]'4.4.0.0') 'Wrong Serilog version.'
Assert-True ($serilog[0].Location -eq (Join-Path $Stage "PoShLog/lib/$target/Serilog.dll")) 'Serilog was not loaded from staged Core.'
Assert-True (@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Serilog.Sinks.Http' }).Count -eq 0) 'Upstream Http was loaded.'
$endpoint = $null
try {
    switch ($Scenario) {
        'Delivery' {
            $endpoint = [PoShLog.Http.Tests.LoopbackEndpoint]::new()
            New-Logger | Add-SinkHttp -RequestUri $endpoint.Url | Start-Logger
            Write-InfoLog 'native {Number}' -PropertyValues 42
            Wait-Until { $endpoint.Requests.Count -gt 0 } 'Eager first delivery did not arrive.'
            Close-Logger
            $request = $endpoint.Requests.ToArray()[0]
            Assert-True ($request.Method -eq 'POST' -and $request.ContentType -eq 'application/json') 'Wrong HTTP metadata.'
            Assert-True ($request.Body.StartsWith('[')) 'Default payload is not an array.'
            Assert-True (!$request.Body.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal)) 'UTF-8 payload contains a BOM.'
            $events = @($request.Body | ConvertFrom-Json)
            Assert-True ($events[0].RenderedMessage -eq 'native 42') 'Rendered schema changed.'
            Assert-True ($events[0].Properties.Number -eq 42) 'Structured property was lost.'
            Assert-True ($request.Body -match '"Timestamp":"[^"]+Z"') 'Timestamp is not UTC.'
        }
        'Recovery' {
            $endpoint = [PoShLog.Http.Tests.LoopbackEndpoint]::new()
            $endpoint.FailuresRemaining = 1
            New-Logger | Add-SinkHttp -RequestUri $endpoint.Url -Period ([timespan]::FromMilliseconds(20)) | Start-Logger
            Write-InfoLog 'recover-marker'
            Wait-Until { $endpoint.Requests.Count -ge 2 } 'Failed batch was not retried.'
            Write-InfoLog 'after-recovery'
            Close-Logger
            $bodies = $endpoint.Requests.ToArray().Body
            Assert-True (@($bodies | Where-Object { $_ -match 'recover-marker' }).Count -ge 2) 'Retry lost the failed batch.'
            Assert-True (($bodies -join '') -match 'after-recovery') 'Sink failed to recover.'
        }
        { $_ -in 'Saturation','Unbounded' } {
            $client = [PoShLog.Http.Tests.RecordingClient]::new()
            $client.Block = $true
            $limit = if ($Scenario -eq 'Unbounded') { $null } else { 2 }
            New-Logger | Add-SinkHttp -RequestUri 'http://127.0.0.1/' -HttpClient $client -QueueLimit $limit -BatchPostingLimit 1 -Period ([timespan]::FromMilliseconds(10)) | Start-Logger
            try {
                Write-InfoLog 'first'
                Assert-True ($client.Started.Wait(5000)) 'First request did not start.'
                foreach ($number in 0..11) { Write-InfoLog 'queued {Index}' -PropertyValues $number }
            } finally {
                $null = $client.Release.TrySetResult($true)
                Close-Logger
            }
            $expected = if ($Scenario -eq 'Unbounded') { 13 } else { 3 }
            Assert-True ($client.Delivered.Count -eq $expected) "Queue admission count: expected $expected, got $($client.Delivered.Count)."
            Assert-True $client.Disposed 'Transport was not disposed after drain.'
        }
        'Custom' {
            $client = [PoShLog.Http.Tests.RecordingClient]::new()
            $configuration = @{ custom = 42 }
            New-Logger | Add-SinkHttp -RequestUri 'http://127.0.0.1/' -HttpClient $client -Configuration $configuration -TextFormatter ([PoShLog.Http.Tests.MarkerFormatter]::new()) -BatchFormatter ([PoShLog.Http.Tests.MarkerBatchFormatter]::new()) | Start-Logger
            Write-InfoLog 'custom'
            Close-Logger
            Assert-True ([object]::ReferenceEquals($configuration, $client.Configuration)) 'Dictionary identity changed.'
            Assert-True $client.CancellationPassed 'Transport did not receive a cancellation token.'
            Assert-True ($client.DisposeCount -eq 1) 'Transport was not disposed exactly once.'
            Assert-True ($client.Delivered.ToArray()[0] -eq '{"customBatch":[{"custom":true}]}') 'Custom formatters were ignored.'
        }
        'Legacy' {
            $endpoint = [PoShLog.Http.Tests.LoopbackEndpoint]::new()
            New-Logger | Add-SinkHttp -RequestUri $endpoint.Url -BatchFormatter ([PoShLog.Sinks.Http.BatchFormatters.LegacyBatchFormatter]::new()) | Start-Logger
            Write-InfoLog 'legacy-marker'
            Close-Logger
            $body = $endpoint.Requests.ToArray()[0].Body
            Assert-True ($body.StartsWith('{"events":[')) 'Legacy envelope changed.'
            Assert-True (($body | ConvertFrom-Json).events[0].RenderedMessage -eq 'legacy-marker') 'Legacy event missing.'
        }
        'Validation' {
            $invalid = @(
                @{ RequestUri = 'relative' }, @{ RequestUri = 'ftp://127.0.0.1/' },
                @{ RequestUri = 'http://127.0.0.1/'; BatchPostingLimit = 0 },
                @{ RequestUri = 'http://127.0.0.1/'; QueueLimit = 0 },
                @{ RequestUri = 'http://127.0.0.1/'; Period = [timespan]::Zero }
            )
            foreach ($options in $invalid) {
                $failed = $false
                try { $null = New-Logger | Add-SinkHttp @options } catch { $failed = $true }
                Assert-True $failed 'Invalid configuration was accepted.'
            }
            $command = Get-Command Add-SinkHttp
            Assert-True ($command.Parameters.Formatter.Aliases -contains 'TextFormatter') 'TextFormatter alias missing.'
            $definition = $command.ScriptBlock.ToString()
            Assert-True ($definition -match '\$QueueLimit = 100000') 'Omitted queue limit is not 100000.'
        }
        'Flush' {
            $endpoint = [PoShLog.Http.Tests.LoopbackEndpoint]::new()
            New-Logger | Add-SinkHttp -RequestUri $endpoint.Url -BatchPostingLimit 3 -Period ([timespan]::FromHours(1)) | Start-Logger
            foreach ($number in 0..19) { Write-InfoLog 'flush {Index}' -PropertyValues $number }
            Close-Logger
            $all = @($endpoint.Requests.ToArray() | ForEach-Object {
                # Desktop ConvertFrom-Json returns an array as one pipeline object; enumerate explicitly.
                $batch = @(foreach ($event in (ConvertFrom-Json -InputObject $_.Body)) { $event })
                Assert-True ($batch.Count -le 3) 'Batch count exceeded its configured limit.'
                $batch
            })
            Assert-True ($all.Count -eq 20) 'Close-Logger did not flush all events.'
            Assert-True (@($all.Properties.Index | Sort-Object -Unique).Count -eq 20) 'Flush duplicated or omitted events.'
        }
        'ApiKey' {
            $endpoint = [PoShLog.Http.Tests.LoopbackEndpoint]::new()
            foreach ($dictionary in $false,$true) {
                $options = @{ HttpClient = (Get-ApiKeyHttpClient -ApiKey 'synthetic-constructor') }
                if ($dictionary) { $options.Configuration = @{ 'http:apiKey' = 'synthetic-dictionary' } }
                New-Logger | Add-SinkHttp -RequestUri $endpoint.Url @options | Start-Logger
                Write-InfoLog 'header-marker'
                Close-Logger
            }
            $requests = $endpoint.Requests.ToArray()
            Assert-True ($requests.Count -eq 2) 'Header probe did not receive both requests.'
            Assert-True ($requests[0].ApiKey -eq 'synthetic-constructor') 'ApiKey parameter was ignored.'
            Assert-True ($requests[1].ApiKey -eq 'synthetic-dictionary') 'Configuration API key did not replace the constructor key.'
        }
        default { throw "Unknown HTTP test scenario: $Scenario" }
    }
} finally {
    Close-Logger
    if ($endpoint) { $endpoint.Dispose() }
}
Write-Output "PASS $Scenario $Order $PSEdition $($PSVersionTable.PSVersion) Serilog=$($serilog[0].GetName().Version)"
