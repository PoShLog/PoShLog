[CmdletBinding()]
param(
    # InRepo: extensions built from this repo. Published: our own published extensions (blocking).
    # ThirdParty: other authors' published sinks, a non-blocking check (ADR 0009).
    [ValidateSet('InRepo', 'Published', 'ThirdParty')]
    [string]$Mode = 'InRepo',
    [string]$GalleryPath = (Join-Path $PSScriptRoot '../../.compat/gallery'),
    # InRepo only: an extracted PoShLog.Sinks.Seq 1.0.0 to load next to the unpublished sinks, for local checks
    # outside GitHub Actions (Published mode downloads it).
    [string]$LegacySeqPath,
    # InRepo only: extracted pinned Gallery package for the Expressions collision regression.
    [string]$LegacyExceptionlessPath,
    [switch]$Desktop,
    # Explicit opt-in for local diagnosis of first-party published packages only.
    [switch]$AllowLocalPublished,
    [string]$CoreManifest
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
if (!$CoreManifest) { $CoreManifest = "$root/src/PoShLog.psd1" }
$CoreManifest = (Resolve-Path $CoreManifest).Path
if ($Desktop -and $Mode -ne 'Published') { throw 'Desktop phase 1 runs Published compatibility only.' }
$modules = [ordered]@{
    'PoShLog.Enrichers' = '1.0.0'
    'PoShLog.Sinks.Seq' = '1.0.0'
    'PoShLog.Sinks.EventLog' = '1.0.0'
    'PoShLog.Sinks.Http' = '1.0.1'
}
if ($Desktop) {
    $modules['PoShLog.Sinks.EventLog'] = '1.0.1'
    # Published Http 1.0.1 binds its bundled Serilog 2, so Add-SinkHttp cannot accept Core's
    # LoggerConfiguration on Desktop (ADR 0034). EventLog 1.0.1 passes configuration only;
    # this suite neither creates an Event Log source nor writes an Event Log entry.
    $modules.Remove('PoShLog.Sinks.Http')
}
$fromGallery = $Mode -ne 'InRepo'
if ($fromGallery -and $env:GITHUB_ACTIONS -ne 'true' -and !($Mode -eq 'Published' -and $AllowLocalPublished)) {
    throw 'Published extensions may only be downloaded and executed in GitHub Actions.'
}
if ($Mode -eq 'Published') {
    $modules['PoShLog.Sinks.Exceptionless'] = '1.0.0'
}
if ($Mode -eq 'ThirdParty') {
    $modules = [ordered]@{}
    $modules['PoShLog.Sinks.Syslog'] = '1.0.0'
    $modules['PoShLog.Sinks.DataDog'] = '0.1.1'
    $modules['PoShLog.Sinks.ElmahIo'] = '4.0.4'
    $modules['PoShLog.Sinks.Splunk'] = '1.0.4'
}
if ($fromGallery) { New-Item -ItemType Directory -Force $GalleryPath | Out-Null }
# Published modules that cannot load on a platform with any PoShLog version (their own defect, not a v3 break).
$knownBroken = @{
    'PoShLog.Sinks.DataDog' = @{
        Linux = 'manifest RootModule is PoShLog.Sinks.Datadog.psm1 but the file is PoShLog.Sinks.DataDog.psm1; Linux paths are case-sensitive'
    }
}
$platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'MacOS' }
$cases = @(@{ Name = 'PoShLog'; Path = $CoreManifest })
foreach ($name in $modules.Keys) {
    if ($name -eq 'PoShLog.Sinks.EventLog' -and !$IsWindows) {
        Write-Output "SKIP $name (Windows only)"
        continue
    }
    $reason = if ($fromGallery -and $knownBroken.ContainsKey($name)) { $knownBroken[$name][$platform] }
    if ($reason) {
        Write-Output "SKIP $name (known broken on ${platform}: $reason)"
        if ($env:GITHUB_ACTIONS -eq 'true') { Write-Output "::warning title=Compatibility $name skipped on ${platform}::$reason" }
        continue
    }
    if ($fromGallery) {
        # Save exact versions without dependencies, so Gallery cannot substitute an older Core.
        $version = $modules[$name]
        $directory = Join-Path $GalleryPath "$name/$version"
        New-Item -ItemType Directory -Force $directory | Out-Null
        $package = Join-Path $GalleryPath "$name.$version.nupkg"
        Invoke-WebRequest "https://www.powershellgallery.com/api/v2/package/$name/$version" -OutFile $package
        [IO.Compression.ZipFile]::ExtractToDirectory($package, $directory, $true)
        $manifest = Join-Path $directory "$name.psd1"
        $data = Import-PowerShellDataFile $manifest
        if ($data.ModuleVersion -ne $version) { throw "Incorrect published version for $name." }
    } else {
        $manifest = "$root/extensions/$name/$name.psd1"
    }
    $cases += @{ Name = $name; Path = $manifest }
    if ($Desktop) { $cases += @{ Name = $name; Path = $manifest; ExtensionFirst = $true } }
}
# The OpenTelemetry, Splunk HEC, Syslog and Elastic sinks are not published yet: always the in-repo builds. Each must load and deliver
# next to the Seq extension in either import order, the refreshed one (InRepo) and the published 1.0.0 that ships its own
# older assemblies (Published); see docs/decisions/0012-otlp-sink-design.md.
$unpublished = @('PoShLog.Sinks.OpenTelemetry', 'PoShLog.Sinks.Splunk.Hec', 'PoShLog.Sinks.Syslog.Rfc5424', 'PoShLog.Sinks.Elastic', 'PoShLog.Sinks.MSSqlServer')
if ($Desktop) { $unpublished = @() }
$seqCase = $cases | Where-Object Name -eq 'PoShLog.Sinks.Seq'
$seqPaths = @()
if ($Mode -eq 'InRepo') {
    foreach ($name in $unpublished) { $cases += @{ Name = $name; Path = "$root/extensions/$name/$name.psd1" } }
    $seqPaths += $seqCase.Path
    if ($LegacySeqPath) { $seqPaths += (Resolve-Path $LegacySeqPath).Path }
} elseif ($Mode -eq 'Published') {
    $seqPaths += $seqCase.Path
}
foreach ($name in $unpublished) {
    foreach ($seqPath in $seqPaths) {
        foreach ($first in $true, $false) {
            $cases += @{ Name = $name; Path = "$root/extensions/$name/$name.psd1"; Seq = $seqPath; SeqFirst = $first }
        }
    }
}
# MSSqlServer must coexist with an actual old DI assembly in every compatibility mode.
if (!$Desktop) {
    dotnet build "$PSScriptRoot/fixtures/DependencyInjection22.csproj" -c Release --configfile "$root/build/nuget.config"
    if ($LASTEXITCODE) { throw 'Building the dependency-conflict fixture failed.' }
    foreach ($order in 'DependencyFirst', 'SinkFirst') {
        & (Join-Path $PSHOME 'pwsh') -NoProfile -File "$PSScriptRoot/Test-MSSqlServerIsolation.ps1" -Order $order
        if ($LASTEXITCODE) { throw "MSSqlServer isolation failed: $order" }
    }
} else {
    dotnet build "$PSScriptRoot/fixtures/CompatHttpListener.csproj" -c Release --configfile "$root/build/nuget.config"
    if ($LASTEXITCODE) { throw 'Building the Desktop HTTP listener failed.' }
}
$failed = @()
foreach ($case in $cases) {
    $order = if ($case.ExtensionFirst) { 'extension-first' } else { 'core-first' }
    $label = "$($case.Name) ($order)"
    if ($case.Seq) { $label += "; SeqFirst=$($case.SeqFirst)" }
    Write-Output "RUN $label ($Mode)"
    $caseFailed = $false
    # One process per module: legacy assemblies must not mask failures in another extension.
    $executable = if ($Desktop) { (Get-Command powershell.exe).Source } else { Join-Path $PSHOME 'pwsh' }
    $startInfo = [Diagnostics.ProcessStartInfo]::new($executable)
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = @('-NoProfile', '-NonInteractive', '-File', "$PSScriptRoot/Test-Extension.ps1", '-Name', $case.Name, '-ModulePath', $case.Path, '-CoreManifest', $CoreManifest)
    if ($case.ExtensionFirst) { $arguments += '-ExtensionFirst' }
    if ($case.Seq) { $arguments += @('-SeqPath', $case.Seq); if ($case.SeqFirst) { $arguments += '-SeqFirst' } }
    foreach ($argument in $arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit(45000)) {
        $process.Kill($true)
        $process.WaitForExit()
        Write-Output "FAIL $label (45-second process timeout)"
        $caseFailed = $true
    } elseif ($process.ExitCode) {
        $caseFailed = $true
    }
    $output = $stdout.GetAwaiter().GetResult()
    $errors = $stderr.GetAwaiter().GetResult()
    Write-Output $output
    if ($errors) { Write-Output $errors }
    if ($caseFailed) { $failed += $label }
    if ($env:GITHUB_ACTIONS -eq 'true' -and $caseFailed) {
        # Annotations are readable through the public API; job logs need a signed-in user.
        $detail = (($output + "`n" + $errors) -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 15) -join '%0A'
        Write-Output "::error title=Compatibility $label ($Mode)::$detail"
    }
    $process.Dispose()
}
if ($failed.Count) { throw "Compatibility failures: $($failed -join ', ')" }
$exceptionlessPath = if ($Mode -eq 'Published') {
    ($cases | Where-Object Name -eq 'PoShLog.Sinks.Exceptionless').Path
} elseif ($Mode -eq 'InRepo') { $LegacyExceptionlessPath }
if ($exceptionlessPath -and !$Desktop) {
    foreach ($order in 'FilterFirst', 'ExtensionFirst') {
        & (Join-Path $PSHOME 'pwsh') -NoProfile -File "$PSScriptRoot/Test-ExceptionlessFilter.ps1" -ModulePath $exceptionlessPath -Order $order
        if ($LASTEXITCODE) { throw "Exceptionless filter compatibility failed: $order" }
    }
}
Write-Output "PASS $Mode compatibility ($($cases.Count) cases)"
