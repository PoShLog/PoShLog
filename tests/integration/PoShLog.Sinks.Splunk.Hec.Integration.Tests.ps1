if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1"; Import-Module PoShLog.Sinks.Splunk.Hec }
Describe 'Splunk HEC and search delivery' {
    It 'indexes all three JSON events through HTTPS HEC' {
        $id = [guid]::NewGuid().ToString('N')
        # This delegate is restricted to the throw-away container endpoint; product code is unchanged.
        $handler = [Net.Http.HttpClientHandler]::new()
        $handler.ServerCertificateCustomValidationCallback = [Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator
        New-Logger | Add-SinkSplunk -Url https://127.0.0.1:8088 -Token '11111111-2222-3333-4444-555555555555' `
            -Index main -HttpMessageHandler $handler | Start-Logger
        Write-IntegrationEvents $id
        $events = Wait-IntegrationEvents -Read {
            $credential = [pscredential]::new('admin', (ConvertTo-SecureString 'Integration-Only-123!' -AsPlainText -Force))
            $body = @{ search = "search index=main `"$id`" | head 10"; output_mode = 'json' }
            $response = Invoke-WebRequest https://127.0.0.1:8089/services/search/jobs/export -Method Post `
                -Credential $credential -SkipCertificateCheck -Body $body -TimeoutSec 10
            foreach ($line in ($response.Content -split "`n" | Where-Object { $_.Trim() })) {
                $result = $line | ConvertFrom-Json
                if ($result.result._raw) { $result.result._raw | ConvertFrom-Json }
            }
        } -Select { $_.Message -like "$id*" -or $_.RenderedMessage -like "$id*" }
        Assert-IntegrationEvents @($events | ForEach-Object {
            [pscustomobject]@{ Level = $_.Level; Message = $_.RenderedMessage; Number = $_.Properties.Number }
        }) $id
    }
    AfterEach { Close-Logger }
}
