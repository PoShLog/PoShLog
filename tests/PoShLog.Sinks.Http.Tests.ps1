#Requires -Version 5.1
# Every scenario/order gets a clean process against a freshly staged dual-target package.
BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/..").Path
    $stage = Join-Path ([IO.Path]::GetTempPath()) ("PoShLog-http-stage-" + [guid]::NewGuid().ToString('N'))
    $modernHost = (Get-Command pwsh -ErrorAction Stop).Source
    foreach ($name in 'PoShLog', 'PoShLog.Sinks.Http') {
        & $modernHost -NoProfile -File "$root/build/Stage-Module.ps1" -Module $name -Destination $stage
        if ($LASTEXITCODE) { throw "Staging $name failed ($LASTEXITCODE)." }
    }
    & dotnet build "$root/tests/http/Fixtures.csproj" -c Release --configfile "$root/build/nuget.config"
    if ($LASTEXITCODE) { throw 'HTTP test fixture build failed.' }
    $hostPath = if ($PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { Join-Path $PSHOME 'pwsh' }
}

Describe 'Native HTTP package' {
    It 'ships only native binaries and both runtime targets' {
        $package = Join-Path $stage 'PoShLog.Sinks.Http'
        $dlls = @(Get-ChildItem $package -Recurse -File -Filter '*.dll')
        $dlls.Count | Should -Be 2
        @($dlls | Where-Object { $_.Name -ne 'PoShLog.Sinks.Http.dll' }).Count | Should -Be 0
        @(Get-ChildItem $package -Recurse -File | Where-Object { $_.Name -in 'Serilog.dll','Serilog.Sinks.Http.dll' -or $_.Name -like 'Microsoft.Extensions.*' }).Count | Should -Be 0
        foreach ($target in 'net472', 'net10.0') {
            Test-Path "$package/lib/$target/PoShLog.Sinks.Http.dll" | Should -BeTrue
        }
        foreach ($notice in 'THIRD-PARTY-NOTICES.txt','Serilog.Sinks.Http.LICENSE') {
            Test-Path "$package/$notice" | Should -BeTrue
        }
        $data = Import-PowerShellDataFile "$package/PoShLog.Sinks.Http.psd1"
        $data.CompatiblePSEditions | Should -Contain 'Desktop'
        $data.CompatiblePSEditions | Should -Contain 'Core'
        $data.PowerShellVersion | Should -Be '5.1'
        $data.PrivateData.PSData.Prerelease | Should -Be 'preview4'
    }

    It 'passes <Scenario> in order <Order> on the current real host' -TestCases @(
        foreach ($order in 'CoreFirst','ExtensionFirst') {
            foreach ($scenario in 'Delivery','Recovery','Saturation','Unbounded','Custom','Legacy','Validation','Flush','ApiKey') {
                @{ Order = $order; Scenario = $scenario }
            }
        }
    ) {
        param($Order, $Scenario)
        $output = & $hostPath -NoProfile -NonInteractive -File "$root/tests/http/Test-NativeHttp.ps1" -Stage $stage -Order $Order -Scenario $Scenario
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match "PASS $Scenario $Order"
    }
}
