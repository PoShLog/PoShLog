if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1"; Import-Module PoShLog.Sinks.EventLog }
Describe 'Windows Event Log delivery' {
    It 'writes and reads levels, rendered messages and properties' {
        $id = [guid]::NewGuid().ToString('N')
        $source = "PoShLog-Integration-$id"
        $start = Get-Date
        try {
            # Registration needs elevation; no changes to existing event sources or logs.
            [Diagnostics.EventLog]::CreateEventSource($source, 'Application')
            New-Logger | Add-SinkEventLog -Source $source -LogName Application -ManageEventSource $false `
                -OutputTemplate '{Message:lj}|Number={Number}{NewLine}{Exception}' | Start-Logger
            Write-IntegrationEvents $id
            $events = Wait-IntegrationEvents -Read {
                Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = $source; StartTime = $start } -ErrorAction Stop
            } -Select { $_.Message -like "$id*" }
            Assert-IntegrationEvents @($events | ForEach-Object {
                [pscustomobject]@{
                    Level = switch ($_.Level) { 4 { 'Information' }; 3 { 'Warning' }; 2 { 'Error' } }
                    Message = ($_.Message -split '\|')[0]
                    Number = if ($_.Message -match '\|Number=(\d+)') { [int]$Matches[1] }
                }
            }) $id
            ($events | Where-Object Level -eq 2).Message | Should -Match 'integration exception'
        } finally {
            Close-Logger
            if ([Diagnostics.EventLog]::SourceExists($source)) { [Diagnostics.EventLog]::DeleteEventSource($source) }
        }
    }
}
