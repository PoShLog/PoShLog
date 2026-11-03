if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll {
    . "$PSScriptRoot/Helpers.ps1"
    Import-Module PoShLog.Sinks.Http
    Add-Type -Path "$PSScriptRoot/../compat/CompatHttpListener.cs"
}
Describe 'HTTP endpoint delivery' {
    It 'posts complete JSON events to a live loopback HttpListener' {
        $id = [guid]::NewGuid().ToString('N')
        $listener = [CompatHttpListener]::new()
        try {
            New-Logger | Add-SinkHttp -RequestUri $listener.Url -Formatter ([Serilog.Formatting.Json.JsonFormatter]::new([Environment]::NewLine, $true)) | Start-Logger
            Write-IntegrationEvents $id
            $events = Wait-IntegrationEvents -Read {
                foreach ($body in $listener.Bodies.ToArray()) {
                    # The default ArrayBatchFormatter posts a JSON array per batch; enumerate its events.
                    $body | ConvertFrom-Json | ForEach-Object { $_ }
                }
            } -Select { $_.RenderedMessage -like "$id*" }
            Assert-IntegrationEvents @($events | ForEach-Object {
                [pscustomobject]@{ Level = $_.Level; Message = $_.RenderedMessage; Number = $_.Properties.Number }
            }) $id
            ($events | Where-Object Level -eq Error).Exception | Should -Match 'integration exception'
        } finally { Close-Logger; $listener.Dispose() }
    }
}
