if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1"; Import-Module PoShLog.Sinks.Seq }
Describe 'Seq server delivery' {
    It 'stores all three events with structured properties' {
        $id = [guid]::NewGuid().ToString('N')
        New-Logger | Add-SinkSeq -ServerUrl http://127.0.0.1:5341 -Compact $true | Start-Logger
        Write-IntegrationEvents $id
        $events = Wait-IntegrationEvents -Read { Read-SeqEvents $id } -Select { $_.Message -like "$id*" }
        Assert-IntegrationEvents $events $id
    }
    AfterEach { Close-Logger }
}
