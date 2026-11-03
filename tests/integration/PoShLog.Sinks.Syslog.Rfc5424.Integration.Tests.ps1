if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll { . "$PSScriptRoot/Helpers.ps1"; Import-Module PoShLog.Sinks.Syslog.Rfc5424 }
Describe 'syslog-ng delivery' {
    It 'stores structured RFC 5424 events over <Protocol>' -ForEach @(
        @{ Protocol = 'Udp'; Port = 514; File = 'udp' }
        @{ Protocol = 'Tcp'; Port = 601; File = 'tcp' }
        @{ Protocol = 'TcpTls'; Port = 6514; File = 'tls' }
    ) {
        $id = [guid]::NewGuid().ToString('N')
        $options = @{ Hostname = '127.0.0.1'; Port = $Port; Protocol = $Protocol }
        if ($Protocol -eq 'TcpTls') {
            $pem = Invoke-BackendCompose exec -T syslog cat /certs/server.crt
            $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($pem)
            $options.TrustedCertificateThumbprint = $cert.GetCertHashString()
        }
        New-Logger | Add-SinkSyslog @options | Start-Logger
        Write-IntegrationEvents $id
        $events = Wait-IntegrationEvents -Read { Read-JsonLines syslog "/output/$File.jsonl" } -Select { $_.MESSAGE -like "$id*" }
        Assert-IntegrationEvents @($events | ForEach-Object {
            $number = $_._SDATA.'poshlog@32473'.Number
            [pscustomobject]@{
                Level = switch ([int]$_.PRI % 8) { 6 { 'Information' }; 4 { 'Warning' }; 3 { 'Error' } }
                Message = ($_.MESSAGE -split '\r?\n')[0]
                Number = $number
            }
        }) $id
    }
    AfterEach { Close-Logger }
}
