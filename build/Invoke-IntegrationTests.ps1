#Requires -Version 7.6
[CmdletBinding()]
param(
    [ValidateSet('Gallery', 'InRepo')][string]$Source = 'Gallery',
    [switch]$Prerelease,
    [string[]]$Module,
    [switch]$WaitForGallery,
    [string]$ResultsPath = (Join-Path (Split-Path $PSScriptRoot) 'TestResults/integration')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$allModules = @('PoShLog', 'PoShLog.Enrichers', 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.Http',
    'PoShLog.Sinks.OpenTelemetry', 'PoShLog.Sinks.Splunk.Hec', 'PoShLog.Sinks.Syslog.Rfc5424', 'PoShLog.Sinks.Elastic', 'PoShLog.Sinks.MSSqlServer')
if (!$Module) { $Module = $allModules }
foreach ($name in $Module) {
    if ($name -notin ($allModules + 'PoShLog.Sinks.EventLog')) { throw "Unknown module: $name" }
    if ($name -eq 'PoShLog.Sinks.EventLog' -and !$IsWindows) { throw 'EventLog requires Windows.' }
}
$selected = @('PoShLog') + @($Module | Where-Object { $_ -ne 'PoShLog' })
if ($Source -eq 'Gallery' -and !$WaitForGallery) {
    # Nightly Gallery runs test what is published. An extension whose current major line is not on the Gallery yet
    # (MSSqlServer 2.x while only 1.0.0-preview1 is published) is skipped instead of testing the old line's API.
    $Module = @(foreach ($name in $Module) {
        if ($name -eq 'PoShLog') { $name; continue }
        $major = ([version](Import-PowerShellDataFile "$root/extensions/$name/$name.psd1").ModuleVersion).Major
        $published = Find-PSResource $name -Prerelease:$Prerelease -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($published -and $published.Version.Major -ge $major) { $name }
        else { Write-Host "::notice title=Integration::Skipping ${name}: the Gallery has no $major.x release yet." }
    })
    $selected = @('PoShLog') + @($Module | Where-Object { $_ -ne 'PoShLog' })
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) "poshlog-integration-$([guid]::NewGuid().ToString('N'))"
$modules = Join-Path $scratch 'Modules'
New-Item -ItemType Directory -Force $modules, $ResultsPath | Out-Null
$ResultsPath = (Resolve-Path $ResultsPath).Path
$originalModulePath = $env:PSModulePath
$originalOptIn = $env:POSHLOG_INTEGRATION
$originalDirectory = [Environment]::CurrentDirectory
$originalLocation = Get-Location
try {
    # Pester itself is isolated too. Never install into the user's module folders.
    Save-PSResource Pester -Version '[5.5.0,6.0.0)' -Path $modules -TrustRepository
    if ($Source -eq 'Gallery') {
        if ($WaitForGallery) {
            # Release events can precede Gallery indexing. Require each checked-out manifest's exact version.
            $deadline = [datetime]::UtcNow.AddMinutes(10)
            do {
                $missing = @()
                foreach ($name in $selected) {
                    $manifestPath = if ($name -eq 'PoShLog') { "$root/src/$name.psd1" } else { "$root/extensions/$name/$name.psd1" }
                    $manifest = Import-PowerShellDataFile $manifestPath
                    $version = [string]$manifest.ModuleVersion
                    if ($manifest.PrivateData.PSData.Prerelease) { $version += '-' + $manifest.PrivateData.PSData.Prerelease }
                    if (!(Find-PSResource $name -Version $version -Prerelease:$Prerelease -ErrorAction SilentlyContinue)) { $missing += $name }
                }
                if (!$missing.Count) { break }
                if ([datetime]::UtcNow -ge $deadline) { throw "Gallery indexing timeout: $missing" }
                Write-Host "Waiting for Gallery indexing: $missing"
                Start-Sleep -Seconds 15
            } while ($true)
        }
        foreach ($name in $selected) {
            # Core is explicitly selected above. Do not let each dependency save overwrite the same
            # numeric version folder with an older prerelease satisfying the extension's minimum.
            Save-PSResource $name -Prerelease:$Prerelease -Path $modules -TrustRepository -SkipDependencyCheck
        }
    } else {
        # Match the CI build: net10.0 for the .NET 10 host in PowerShell 7.6 (ADR 0033).
        & "$root/build/Build-Core.ps1"
        if ($LASTEXITCODE) { throw 'Core publish failed.' }
        foreach ($name in $selected) { & "$PSScriptRoot/Stage-Module.ps1" -Module $name -Destination $modules }
    }
    # Fresh children inherit only the staged packages and built-in modules, avoiding assembly/version contamination.
    $env:PSModulePath = $modules + [IO.Path]::PathSeparator + (Join-Path $PSHOME 'Modules')
    $env:POSHLOG_INTEGRATION = '1'
    Get-Module PoShLog* | Remove-Module -Force
    $versions = foreach ($name in $selected) {
        $resolved = Get-Module -ListAvailable $name | Sort-Object Version -Descending | Select-Object -First 1
        if (!$resolved) { throw "Missing staged module: $name" }
        $label = $resolved.PrivateData.PSData.Prerelease
        $version = [string]$resolved.Version
        if ($label) { $version += "-$label" }
        Write-Host "Resolved $name $version"
        [pscustomobject]@{ Name = $name; Version = $version; Path = $resolved.Path }
    }
    $versions | ConvertTo-Json | Set-Content "$ResultsPath/resolved-$Source.json"
    $failed = $false
    foreach ($name in $Module) {
        $test = Join-Path $root "tests/integration/$name.Integration.Tests.ps1"
        $output = Join-Path $ResultsPath "$Source-$name.xml"
        $env:POSHLOG_INTEGRATION_TEST = $test
        $env:POSHLOG_INTEGRATION_RESULT = $output
        # Seq 1.0.x can leave durable buffers in the process working directory. Keep all such writes isolated.
        Set-Location $scratch
        [Environment]::CurrentDirectory = $scratch
        & (Join-Path $PSHOME 'pwsh') -NoProfile -Command {
            $ErrorActionPreference = 'Stop'
            Import-Module Pester -MinimumVersion 5.5.0 -MaximumVersion 5.99.0
            $config = New-PesterConfiguration
            $config.Run.Path = $env:POSHLOG_INTEGRATION_TEST
            $config.Run.PassThru = $true
            $config.Output.Verbosity = 'Detailed'
            $config.TestResult.Enabled = $true
            $config.TestResult.OutputPath = $env:POSHLOG_INTEGRATION_RESULT
            $result = Invoke-Pester -Configuration $config
            # The job log needs sign-in; annotations show the failure reason on the run page.
            if ($env:GITHUB_ACTIONS -eq 'true') {
                foreach ($test in $result.Failed) {
                    $reason = ($test.ErrorRecord | ForEach-Object { $_.Exception.Message }) -join ' ' -replace '\r?\n', ' '
                    Write-Host "::error title=$($test.ExpandedPath)::$reason"
                }
            }
            if ($result.FailedCount -or $result.FailedContainersCount -or !$result.PassedCount) { exit 1 }
        }
        if ($LASTEXITCODE) { $failed = $true }
    }
    if ($failed) { throw 'Integration tests failed. See the Pester summaries and result XML.' }
} finally {
    Set-Location $originalLocation
    [Environment]::CurrentDirectory = $originalDirectory
    $env:PSModulePath = $originalModulePath
    $env:POSHLOG_INTEGRATION = $originalOptIn
    Remove-Item Env:POSHLOG_INTEGRATION_TEST, Env:POSHLOG_INTEGRATION_RESULT -ErrorAction SilentlyContinue
    # Only remove the GUID directory created above, after checking its absolute parent and prefix.
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    if ((Split-Path $resolvedScratch) -eq [IO.Path]::GetTempPath().TrimEnd('\', '/') -and
        (Split-Path $resolvedScratch -Leaf) -like 'poshlog-integration-*') {
        Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
    }
}
