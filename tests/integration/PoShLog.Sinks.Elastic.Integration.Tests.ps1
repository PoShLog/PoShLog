if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1"; Import-Module PoShLog.Sinks.Elastic }
Describe 'Elasticsearch 8 delivery (security disabled)' {
    It 'indexes ECS documents into a real data stream' {
        $id = [guid]::NewGuid().ToString('N')
        $stream = "logs-integration-$id"
        New-Logger | Add-SinkElasticsearch -Node http://127.0.0.1:9200 -DataStream $stream | Start-Logger
        Write-IntegrationEvents $id
        $events = Wait-IntegrationEvents -Read {
            Invoke-RestMethod "http://127.0.0.1:9200/$stream/_refresh" -Method Post -TimeoutSec 10 | Out-Null
            $body = @{ query = @{ match_phrase = @{ message = $id } }; size = 10 } | ConvertTo-Json -Depth 5
            (Invoke-RestMethod "http://127.0.0.1:9200/$stream/_search" -Method Post -ContentType application/json -Body $body -TimeoutSec 10).hits.hits._source
        } -Select { $_.message -like "$id*" }
        Assert-IntegrationEvents @($events | ForEach-Object {
            [pscustomobject]@{ Level = $_.'log.level'; Message = $_.message; Number = $_.metadata.Number }
        }) $id
    }
    AfterEach { Close-Logger }
}
