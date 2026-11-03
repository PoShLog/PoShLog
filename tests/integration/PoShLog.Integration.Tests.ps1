# Ordinary CI recursively discovers tests/; only the dedicated runner opts in.
if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1" }
Describe 'Core File sink delivery' {
    It 'flushes levels, rendered messages, properties and the ErrorRecord to JSON' {
        $id = [guid]::NewGuid().ToString('N')
        $file = Join-Path $TestDrive 'events.jsonl'
        New-Logger | Add-SinkFile -Path $file -Formatter ([Serilog.Formatting.Json.JsonFormatter]::new([Environment]::NewLine, $true)) | Start-Logger
        Write-IntegrationEvents $id
        $events = Wait-IntegrationEvents -Read { Get-Content $file | ConvertFrom-Json } -Select { $_.RenderedMessage -like "$id*" }
        Assert-IntegrationEvents @($events | ForEach-Object {
            [pscustomobject]@{ Level = $_.Level; Message = $_.RenderedMessage; Number = $_.Properties.Number }
        }) $id
        ($events | Where-Object Level -eq Error).Exception | Should -Match 'integration exception'
    }
    AfterEach { Close-Logger }
}
