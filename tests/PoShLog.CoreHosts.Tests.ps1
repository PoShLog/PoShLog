#Requires -Version 5.1

BeforeAll {
    $manifest = if ($env:POSHLOG_TEST_MANIFEST) { $env:POSHLOG_TEST_MANIFEST } else { "$PSScriptRoot/../src/PoShLog.psd1" }
    Import-Module $manifest -Force -ErrorAction Stop
}

Describe 'Core on supported PowerShell hosts' {
    AfterEach { Close-Logger }

    It 'preserves exit <ExitCode> in a new -File process using #Requires' -TestCases @(
        @{ ExitCode = 0 }
        @{ ExitCode = 1 }
        @{ ExitCode = 17 }
    ) {
        param($ExitCode)
        $scriptPath = Join-Path $TestDrive "requires-exit-$ExitCode.ps1"
        $requiredManifest = (Resolve-Path $manifest).Path.Replace("'", "''")
        @"
#Requires -Modules '$requiredManifest'
Write-Output 'required module loaded'
exit $ExitCode
"@ | Set-Content $scriptPath -Encoding UTF8
        $hostPath = if ($PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { Join-Path $PSHOME 'pwsh' }
        $output = & $hostPath -NoProfile -NonInteractive -File $scriptPath
        $actualExitCode = $LASTEXITCODE
        $output | Should -Be 'required module loaded'
        $actualExitCode | Should -Be $ExitCode
    }

    It 'exports the manifest commands through the script module' {
        $data = Import-PowerShellDataFile $manifest
        @(Get-Command -Module PoShLog -Name *).Name | Sort-Object | Should -Be ($data.CmdletsToExport | Sort-Object)
        $data.RootModule | Should -Be 'PoShLog.psm1'
        $data.ContainsKey('RequiredAssemblies') | Should -BeFalse
        @(Get-PoShLogExtension).Count | Should -BeGreaterThan 0
    }

    It 'flushes a buffered file and releases its handle on disposal' {
        $file = Join-Path $TestDrive 'buffered.log'
        $logger = New-Logger | Add-SinkFile -Path $file -Buffered -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger -PassThru
        Write-InfoLog 'buffered marker' -Logger $logger
        $logger | Close-Logger
        Get-Content $file -Raw | Should -Match 'buffered marker'
        $stream = [IO.File]::Open($file, 'Open', 'ReadWrite', 'None')
        $stream.Dispose()
    }

    It 'applies live level switches and property enrichment' {
        $file = Join-Path $TestDrive 'switch.json'
        $switch = New-LevelSwitch -MinimumLevel Warning
        New-Logger | Set-MinimumLevel -ControlledBy $switch | Add-EnrichWithProperty -Name HostKind -Value $PSEdition |
            Add-SinkFile -Path $file -Formatter (Get-JsonFormatter) | Start-Logger
        Write-InfoLog 'excluded marker'
        $switch | Set-LevelSwitch -MinimumLevel Information
        Write-InfoLog 'included marker'
        Close-Logger
        $events = @(Get-Content $file | ConvertFrom-Json)
        $events.Count | Should -Be 1
        $events[0].Properties.HostKind | Should -Be $PSEdition
        $events[0].MessageTemplate | Should -Be 'included marker'
    }

    It 'reads non-expression JSON with levels, properties, context and relative file paths' {
        Push-Location $TestDrive
        try {
            '{"Serilog":{"MinimumLevel":{"Default":"Warning","Override":{"Framework":"Error"}},"Properties":{"App":"Core","Nested":{"Value":7}},"Enrich":["FromLogContext"],"WriteTo":[{"Name":"File","Args":{"path":"./configured.json","outputTemplate":"{App} {Job} {Message:lj}{NewLine}","buffered":true}}]}}' |
                Set-Content './logging.json' -Encoding UTF8
            New-Logger -ConfigurationPath './logging.json' | Start-Logger
            Write-InfoLog 'excluded'
            Push-LogContextProperty Job nightly -ScriptBlock { Write-WarningLog 'configured marker' }
            Close-Logger
            Get-Content './configured.json' -Raw | Should -Be "Core nightly configured marker$([Environment]::NewLine)"
        } finally { Pop-Location }
    }

    It 'converts a script with an atomic replacement and preserves its backup' {
        $file = Join-Path $TestDrive 'convert.ps1'
        "Write-Warning 'message'" | Set-Content $file -Encoding UTF8
        Convert-LogFunctions -Path $file -Confirm:$false | Out-Null
        Get-Content $file -Raw | Should -Match 'Write-WarningLog'
        Get-Content "$file.bak" -Raw | Should -Match "Write-Warning 'message'"
    }

    It 'rejects expression filters without loading their engine on Desktop' -Skip:($PSEdition -ne 'Desktop') -Tag 'DesktopOnly' {
        $child = New-Logger | Start-Logger -PassThru
        try {
            { New-Logger | Add-SinkLogger -Logger $child -Filter 'Send = true' -ErrorAction Stop } |
                Should -Throw '*not supported on Windows PowerShell*'
            '{"Serilog":{"Filter":[{"Name":"ByIncludingOnly","Args":{"expression":"Send = true"}}]}}' |
                Set-Content "$TestDrive/filter.json" -Encoding UTF8
            { New-Logger -ConfigurationPath "$TestDrive/filter.json" -ErrorAction Stop } |
                Should -Throw '*not supported on Windows PowerShell*'
            @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Serilog.Expressions' }).Count | Should -Be 0
            (Get-Command New-Logger).ImplementingType.Assembly.GetType('Serilog.Expressions.SerilogExpression') | Should -BeNullOrEmpty
        } finally { $child.Dispose() }
    }
}
