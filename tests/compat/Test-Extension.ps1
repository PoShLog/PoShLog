[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$ModulePath,
    # A Seq extension imported into the same session, to prove both load and deliver side by side.
    [string]$SeqPath,
    [switch]$SeqFirst,
    [switch]$ExtensionFirst,
    [string]$CoreManifest
)
$ErrorActionPreference = 'Stop'
function Write-AssemblyDiagnostics {
    foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -like 'Serilog*' -or $_.GetName().Name -eq 'System.Diagnostics.EventLog' }) {
        Write-Output "ASSEMBLY $($assembly.FullName) | $($assembly.Location)"
    }
    foreach ($command in Get-Command New-Logger, Add-SinkHttp -ListImported -ErrorAction SilentlyContinue) {
        foreach ($parameter in $command.Parameters.Values | Where-Object { $_.ParameterType.FullName -like 'Serilog.*' }) {
            Write-Output "PARAMETER $($command.Name) -$($parameter.Name) | $($parameter.ParameterType.AssemblyQualifiedName) | $($parameter.ParameterType.Assembly.Location)"
        }
    }
}
trap {
    $failure = $_
    try { Write-AssemblyDiagnostics } catch { Write-Output "Assembly diagnostics failed: $_" }
    throw $failure
}
$root = (Resolve-Path "$PSScriptRoot/../..").Path
if (!$CoreManifest) { $CoreManifest = "$root/src/PoShLog.psd1" }
$CoreManifest = (Resolve-Path $CoreManifest).Path
$ModulePath = (Resolve-Path $ModulePath).Path
if ($SeqPath) { $SeqPath = (Resolve-Path $SeqPath).Path }
if ($PSEdition -eq 'Desktop') {
    # RequiredModules in published extensions must discover the staged v3, including extension-first imports.
    $env:PSModulePath = (Split-Path (Split-Path $CoreManifest)) + [IO.Path]::PathSeparator + (Join-Path $PSHOME 'Modules')
}
if ($ExtensionFirst -and $Name -ne 'PoShLog') { Import-Module (Resolve-Path $ModulePath) -Force }
Import-Module $CoreManifest -Force
$shared = @('Serilog', 'Serilog.Sinks.File', 'Serilog.Sinks.Console')
foreach ($assembly in $shared) {
    $loaded = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $assembly }
    if ($PSEdition -ne 'Desktop' -and $loaded -and [Runtime.Loader.AssemblyLoadContext]::GetLoadContext($loaded) -ne [Runtime.Loader.AssemblyLoadContext]::Default) { throw "$assembly is isolated from extensions." }
    $target = if ($PSEdition -eq 'Desktop') { 'net472' } else { 'net10.0' }
    if (!$loaded -or $loaded.Location -ne (Join-Path (Split-Path $CoreManifest) "lib/$target/$assembly.dll")) {
        throw "Core did not preload $assembly from lib/$target."
    }
}
if ($SeqPath -and $SeqFirst) { Import-Module (Resolve-Path $SeqPath) -Force }
if ($Name -ne 'PoShLog' -and !$ExtensionFirst) { Import-Module (Resolve-Path $ModulePath) -Force }
if ($SeqPath -and !$SeqFirst) { Import-Module (Resolve-Path $SeqPath) -Force }
Write-AssemblyDiagnostics
if ($PSEdition -eq 'Desktop') {
    $null = [Reflection.Assembly]::LoadFrom("$PSScriptRoot/fixtures/bin/Release/net472/CompatHttpListener.dll")
} else { Add-Type -Path "$PSScriptRoot/CompatHttpListener.cs" }
$listener = $null
$seqListener = $null
$udp = $null
$marker = "compat-$([guid]::NewGuid().ToString('N'))"
$directory = Join-Path $root ".compat/$marker"
New-Item -ItemType Directory -Force $directory | Out-Null
# Seq 1.0.0 passes an empty buffer file name and so ships durably from files in the current directory
# (-YYYYMMDD.json, .bookmark); keep them in the case's own folder, not in the checkout.
Set-Location $directory
[Environment]::CurrentDirectory = $directory
$file = Join-Path $directory 'event.json'
try {
    $config = New-Logger
    Write-Output "CONFIGURATION $($config.GetType().AssemblyQualifiedName) | $($config.GetType().Assembly.Location)"
    $delivery = 'file'
    switch ($Name) {
        'PoShLog' { }
        'PoShLog.Enrichers' {
            $config = $config | Add-EnrichWithEnvironment | Add-EnrichWithProcessId |
                Add-EnrichWithProcessName | Add-EnrichWithExceptionDetails
        }
        'PoShLog.Sinks.Seq' {
            $listener = [CompatHttpListener]::new()
            $config = $config | Add-SinkSeq -ServerUrl $listener.Url -Period ([timespan]::FromMilliseconds(100))
            $delivery = 'http'
        }
        'PoShLog.Sinks.OpenTelemetry' {
            $listener = [CompatHttpListener]::new()
            $config = $config | Add-SinkOpenTelemetry -Endpoint $listener.Url -Protocol HttpProtobuf -IgnoreEnvironment -Period ([timespan]::FromMilliseconds(100))
            $delivery = 'http'
        }
        'PoShLog.Sinks.Splunk.Hec' {
            $listener = [CompatHttpListener]::new()
            $config = $config | Add-SinkSplunk -Url $listener.Url -Token 'compat-placeholder' -Index 'main' -BatchInterval 0.1
            $delivery = 'http'
        }
        'PoShLog.Sinks.Http' {
            $listener = [CompatHttpListener]::new()
            $options = @{ RequestUri = $listener.Url; Period = [timespan]::FromMilliseconds(100); BatchPostingLimit = 1; QueueLimit = 10 }
            if ($ModulePath -and (Import-PowerShellDataFile $ModulePath).CmdletsToExport -contains 'Get-ApiKeyHttpClient') {
                # First-party modules must export their declared authentication helper.
                $options.HttpClient = Get-ApiKeyHttpClient -ApiKey 'compat-placeholder' -ErrorAction Stop
            } elseif ((Get-Command Get-ApiKeyHttpClient -ErrorAction SilentlyContinue)) {
                $options.HttpClient = Get-ApiKeyHttpClient -ApiKey 'compat-placeholder'
            }
            $config = $config | Add-SinkHttp @options
            $delivery = 'http'
        }
        'PoShLog.Sinks.MSSqlServer' {
            # Real delivery is covered by integration; this exercises construction in a fresh process.
            $config = $config | Add-SinkMSSqlServer -ConnectionString 'Server=127.0.0.1,1;Database=master;Integrated Security=true;Connect Timeout=1' -RestrictedToMinimumLevel Fatal -ColumnOptions @{ Store = @('Id', 'Message', 'Level', 'LogEvent') }
            $delivery = 'configuration'
        }
        'PoShLog.Sinks.EventLog' {
            # Build the sink without creating an event source or requiring elevation.
            $config = $config | Add-SinkEventLog -Source 'Application' -LogName Application -ManageEventSource $false
            $delivery = 'configuration'
        }
        'PoShLog.Sinks.Syslog' {
            $udp = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
            $port = ([Net.IPEndPoint]$udp.Client.LocalEndPoint).Port
            if ($port -eq 5240) { throw 'Reserved port selected unexpectedly.' }
            $received = $udp.ReceiveAsync()
            $config = $config | Add-SinkSyslogUdp -Hostname '127.0.0.1' -Port $port
            $delivery = 'udp'
        }
        'PoShLog.Sinks.Syslog.Rfc5424' {
            $udp = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
            $port = ([Net.IPEndPoint]$udp.Client.LocalEndPoint).Port
            $received = $udp.ReceiveAsync()
            $config = $config | Add-SinkSyslog -Hostname '127.0.0.1' -Port $port -BatchInterval 0.1
            $delivery = 'udp'
        }
        'PoShLog.Sinks.Elastic' {
            $listener = [CompatHttpListener]::new()
            $config = $config | Add-SinkElasticsearch -Node $listener.Url -ApiKey 'compat-placeholder' -BatchInterval 1
            $delivery = 'http'
        }
        'PoShLog.Sinks.Splunk' {
            $listener = [CompatHttpListener]::new()
            $config = $config | Add-SinkSplunk -SplunkHost $listener.Url -EventCollectorToken 'compat-placeholder' -BatchIntervalSeconds 1
            $delivery = 'http'
        }
        'PoShLog.Sinks.DataDog' {
            $listener = [CompatHttpListener]::new()
            $options = [Serilog.Sinks.Datadog.Logs.DatadogConfiguration]::new()
            $options.Url = $listener.Url.TrimEnd('/')
            $options.Port = ([uri]$listener.Url).Port
            $options.UseSSL = $false
            $options.UseTCP = $false
            $config = $config | Add-SinkDataDog -ApiKey 'compat-placeholder' -Configuration $options -Period ([timespan]::FromMilliseconds(100))
            $delivery = 'http'
        }
        'PoShLog.Sinks.Exceptionless' {
            $listener = [CompatHttpListener]::new()
            $config = $config | Add-SinkExceptionless -ApiKey 'compat-placeholder-key' -ServerUrl $listener.Url
            $delivery = 'http'
        }
        'PoShLog.Sinks.ElmahIo' {
            # No endpoint parameter: configure without sending to the hosted service.
            $config = $config | Add-SinkElmahIo -ApiKey 'compat-placeholder' -LogId ([guid]::NewGuid()) -RestrictedToMinimumLevel Fatal
            $delivery = 'configuration'
        }
        default { throw "No compatibility case for $Name." }
    }
    if ($SeqPath) {
        $seqListener = [CompatHttpListener]::new()
        $config = $config | Add-SinkSeq -ServerUrl $seqListener.Url -Period ([timespan]::FromMilliseconds(100))
    }
    if ($config -isnot [Serilog.LoggerConfiguration]) { throw "$Name broke the configuration pipeline." }
    $config | Add-SinkFile -Path $file -Formatter (Get-JsonFormatter) | Start-Logger
    if ($delivery -ne 'configuration' -or $seqListener) {
        Write-InfoLog $marker
    }
    if ($delivery -in @('http', 'udp')) {
        $deadline = [datetime]::UtcNow.AddSeconds(30)
        do {
            if ($delivery -eq 'http') { $body = $listener.Bodies.ToArray() -join "`n" }
            elseif ($received.IsCompletedSuccessfully) { $body = [Text.Encoding]::UTF8.GetString($received.Result.Buffer) }
            if ($body -like "*$marker*") { break }
            Start-Sleep -Milliseconds 100
        } while ([datetime]::UtcNow -lt $deadline)
        if ($body -notlike "*$marker*") { throw "$Name did not deliver the event to loopback within 30 seconds." }
        if ($Name -eq 'PoShLog.Sinks.OpenTelemetry' -and $listener.Paths.ToArray() -notcontains '/v1/logs') { throw 'OTLP/HTTP export did not use /v1/logs.' }
        if ($Name -eq 'PoShLog.Sinks.Splunk.Hec' -and $listener.Paths.ToArray() -notcontains '/services/collector/event') { throw 'Splunk HEC request did not use /services/collector/event.' }
        if ($Name -eq 'PoShLog.Sinks.Elastic' -and !($listener.Paths.ToArray() -like '/logs-poshlog-default/_bulk*')) { throw 'Elasticsearch request did not use the bulk API of logs-poshlog-default.' }
        if ($Name -eq 'PoShLog.Sinks.Syslog.Rfc5424' -and $body -notmatch '^<\d{1,3}>1 ') { throw 'Syslog datagram is not an RFC 5424 message.' }
    }
    if ($seqListener) {
        $deadline = [datetime]::UtcNow.AddSeconds(30)
        while (($seqListener.Bodies.ToArray() -join "`n") -notlike "*$marker*" -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        if (($seqListener.Bodies.ToArray() -join "`n") -notlike "*$marker*") { throw "Seq from $SeqPath did not deliver the event next to $Name." }
    }
    Close-Logger
    if ($delivery -ne 'configuration') {
        $json = Get-Content $file -Raw
        if ($json -notlike "*$marker*") { throw 'Core file sink did not receive the event.' }
        if ($Name -eq 'PoShLog.Enrichers') {
            $properties = ($json | ConvertFrom-Json).Properties
            foreach ($property in @('MachineName', 'EnvironmentUserName', 'ProcessId', 'ProcessName')) {
                if (!$properties.PSObject.Properties[$property]) { throw "Missing enricher property $property." }
            }
        }
    }
    $alongside = if ($SeqPath) { ", with Seq " + (Import-PowerShellDataFile $SeqPath).ModuleVersion + $(if ($SeqFirst) { ' imported first' } else { ' imported after' }) } else { '' }
    Write-Output "PASS $Name ($delivery$alongside; extensionFirst=$ExtensionFirst; host=$($PSVersionTable.PSVersion))"
} finally {
    Close-Logger
    if ($listener) { $listener.Dispose() }
    if ($seqListener) { $seqListener.Dispose() }
    if ($udp) { $udp.Dispose() }
}
