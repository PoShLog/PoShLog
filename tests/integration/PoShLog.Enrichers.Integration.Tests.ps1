if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1"; Import-Module PoShLog.Enrichers }
Describe 'Enrichers delivery through File JSON' {
    It 'preserves environment, process and exception details' {
        $id = [guid]::NewGuid().ToString('N')
        $file = Join-Path $TestDrive 'enriched.jsonl'
        New-Logger | Add-EnrichWithEnvironment | Add-EnrichWithProcessId | Add-EnrichWithProcessName |
            Add-EnrichWithExceptionDetails |
            Add-SinkFile -Path $file -Formatter ([Serilog.Formatting.Json.JsonFormatter]::new([Environment]::NewLine, $true)) | Start-Logger
        Write-IntegrationEvents $id
        $events = Wait-IntegrationEvents -Read { Get-Content $file | ConvertFrom-Json } -Select { $_.RenderedMessage -like "$id*" }
        Assert-IntegrationEvents @($events | ForEach-Object {
            [pscustomobject]@{ Level = $_.Level; Message = $_.RenderedMessage; Number = $_.Properties.Number }
        }) $id
        foreach ($event in $events) {
            $event.Properties.MachineName | Should -Be ([Environment]::MachineName)
            $event.Properties.EnvironmentUserName | Should -Not -BeNullOrEmpty
            $event.Properties.ProcessId | Should -Be $PID
            $event.Properties.ProcessName | Should -Be ([Diagnostics.Process]::GetCurrentProcess().ProcessName)
        }
        ($events | Where-Object Level -eq Error).Properties.ExceptionDetail | Should -Not -BeNullOrEmpty
    }
    AfterEach { Close-Logger }
}
