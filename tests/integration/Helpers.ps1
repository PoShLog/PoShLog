# Shared by integration tests only; no source-tree module imports are allowed here.
$ErrorActionPreference = 'Stop'
Import-Module PoShLog

function Invoke-BackendCompose {
    $output = & docker compose -f "$PSScriptRoot/compose.yml" @args 2>&1
    if ($LASTEXITCODE) { throw "docker compose failed: $output" }
    $output -join "`n"
}

function Wait-IntegrationEvents {
    param([scriptblock]$Read, [scriptblock]$Select, [int]$TimeoutSeconds = 60)
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    $lastError = $null
    do {
        try {
            $events = @(& $Read | Where-Object $Select)
            if ($events.Count -ge 3) { return $events }
        } catch { $lastError = $_.Exception.Message }
        Start-Sleep -Milliseconds 500
    } while ([datetime]::UtcNow -lt $deadline)
    throw "Timed out waiting for three events. Last read error: $lastError"
}

function Write-IntegrationEvents {
    param([string]$RunId)
    Write-InfoLog "$RunId Information {Number}" -PropertyValues 42
    Write-WarningLog "$RunId Warning {Number}" -PropertyValues 42
    try { throw [InvalidOperationException]::new('integration exception') }
    catch { $record = $_ }
    Write-ErrorLog "$RunId Error {Number}" -PropertyValues 42 -ErrorRecord $record
    Close-Logger
}

function Assert-IntegrationEvents {
    param($Events, [string]$RunId)
    @($Events).Count | Should -Be 3
    foreach ($level in 'Information', 'Warning', 'Error') {
        $event = @($Events | Where-Object Level -eq $level)
        $event.Count | Should -Be 1
        $event[0].Message | Should -Be "$RunId $level 42"
        $event[0].Number | Should -Be 42
    }
}

function Read-SeqEvents {
    param([string]$RunId)
    # The events resource returns the rendered message and typed property values.
    $filter = [uri]::EscapeDataString("Contains(@Message, '$RunId')")
    $events = Invoke-RestMethod "http://127.0.0.1:5341/api/events?filter=$filter&count=100&render=true" -TimeoutSec 10
    foreach ($event in $events) {
        $properties = @{}
        foreach ($property in $event.Properties) { $properties[$property.Name] = $property.Value }
        [pscustomobject]@{ Level = $event.Level; Message = $event.RenderedMessage; Number = $properties.Number; Properties = $properties }
    }
}

function Read-JsonLines {
    param([string]$Service, [string]$Path)
    # Collector's distroless image has no cat/shell. Copy the mounted output through Docker's API.
    $copy = [IO.Path]::GetTempFileName()
    try {
        Invoke-BackendCompose cp "${Service}:$Path" $copy | Out-Null
        $text = Get-Content -LiteralPath $copy -Raw
    } finally { Remove-Item -LiteralPath $copy -Force }
    foreach ($line in ($text -split "`n" | Where-Object { $_.Trim() })) { $line | ConvertFrom-Json }
}
