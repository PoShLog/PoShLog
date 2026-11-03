if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1"; Import-Module PoShLog.Sinks.OpenTelemetry }
Describe 'OpenTelemetry Collector delivery' {
    It 'exports structured records over <Protocol>' -ForEach @(
        @{ Protocol = 'HttpProtobuf'; Port = 4318 }, @{ Protocol = 'Grpc'; Port = 4317 }
    ) {
        $id = [guid]::NewGuid().ToString('N')
        New-Logger | Add-SinkOpenTelemetry -Endpoint "http://127.0.0.1:$Port" -Protocol $Protocol -IgnoreEnvironment | Start-Logger
        Write-IntegrationEvents $id
        $events = Wait-IntegrationEvents -Read {
            foreach ($batch in (Read-JsonLines collector /output/logs.jsonl)) {
                foreach ($resource in $batch.resourceLogs) {
                    foreach ($scope in $resource.scopeLogs) {
                        foreach ($record in $scope.logRecords) {
                            $attributes = @{}
                            foreach ($attribute in $record.attributes) { $attributes[$attribute.key] = $attribute.value }
                            [pscustomobject]@{
                                Level = switch ($record.severityNumber) { 9 { 'Information' }; 13 { 'Warning' }; 17 { 'Error' } }
                                Message = $record.body.stringValue
                                Number = $attributes.Number.intValue
                            }
                        }
                    }
                }
            }
        } -Select { $_.Message -like "$id*" }
        Assert-IntegrationEvents $events $id
    }
    AfterEach { Close-Logger }
}
