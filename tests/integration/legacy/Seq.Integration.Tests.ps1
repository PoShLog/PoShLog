if ($env:POSHLOG_LEGACY -ne '1') { return }
BeforeAll {
    . "$PSScriptRoot/../Helpers.ps1"
    Import-Module PoShLog.Sinks.Seq
    # This C# 5 listener also works with Windows PowerShell's built-in compiler.
    Add-Type -Path "$PSScriptRoot/../LegacySeqListener.cs"

    # Seq accepts two raw formats on /api/events/raw: the JSON envelope {"Events":[...]} that Seq 1.0.x sends
    # (it ignores -Compact) and CLEF lines. Normalise both to level, template, property and exception.
    function ConvertFrom-SeqPayload {
        param([string]$Body)
        if ($Body.TrimStart().StartsWith('{"Events"')) {
            foreach ($event in ($Body | ConvertFrom-Json).Events) {
                [pscustomobject]@{ Level = $event.Level; Template = $event.MessageTemplate; Number = $event.Properties.Number; Exception = $event.Exception }
            }
        } else {
            foreach ($line in ($Body -split "`n" | Where-Object { $_.Trim() })) {
                $event = $line | ConvertFrom-Json
                $level = if ($event.'@l') { $event.'@l' } else { 'Information' }
                [pscustomobject]@{ Level = $level; Template = $event.'@mt'; Number = $event.Number; Exception = $event.'@x' }
            }
        }
    }
}
Describe 'Stable v2 Seq ingestion contract (Windows PowerShell 5.1)' {
    It 'posts events with levels, templates and structured properties to the raw endpoint' {
        $id = [guid]::NewGuid().ToString('N')
        $listener = New-Object LegacySeqListener
        try {
            New-Logger | Add-SinkSeq -ServerUrl $listener.Url -Compact $true -Period ([timespan]::FromMilliseconds(100)) | Start-Logger
            Write-IntegrationEvents $id
            $events = Wait-IntegrationEvents -Read {
                foreach ($body in $listener.Bodies.ToArray()) { ConvertFrom-SeqPayload $body }
            } -Select { $_.Template -like "$id*" }
            Assert-IntegrationEvents @($events | ForEach-Object {
                # Both formats carry a template + typed values. Render this simple numeric template for comparison.
                [pscustomobject]@{ Level = $_.Level; Message = $_.Template.Replace('{Number}', [string]$_.Number); Number = $_.Number }
            }) $id
            @($listener.Paths.ToArray() | Where-Object { $_ -like '/api/events/raw*' }).Count | Should -BeGreaterThan 0
            ($events | Where-Object Level -eq 'Error').Exception | Should -Match 'integration exception'
        } finally { Close-Logger; $listener.Dispose() }
    }
}
