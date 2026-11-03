[CmdletBinding()]
param(
    # InRepo: extensions built from this repo. Published: our own published extensions (blocking).
    # ThirdParty: other authors' published sinks, a non-blocking check (ADR 0009).
    [ValidateSet('InRepo', 'Published', 'ThirdParty')]
    [string]$Mode = 'InRepo',
    [string]$GalleryPath = (Join-Path $PSScriptRoot '../../.compat/gallery'),
    # InRepo only: an extracted PoShLog.Sinks.Seq 1.0.0 to load next to the OpenTelemetry sink, for local checks
    # outside GitHub Actions (Published mode downloads it).
    [string]$LegacySeqPath
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$modules = [ordered]@{
    'PoShLog.Enrichers' = '1.0.0'
    'PoShLog.Sinks.Seq' = '1.0.0'
    'PoShLog.Sinks.EventLog' = '1.0.0'
    'PoShLog.Sinks.Http' = '1.0.1'
}
$fromGallery = $Mode -ne 'InRepo'
if ($fromGallery -and $env:GITHUB_ACTIONS -ne 'true') {
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
$cases = @(@{ Name = 'PoShLog'; Path = "$root/src/PoShLog.psd1" })
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
}
# The OpenTelemetry sink is not published yet: always the in-repo build. It must load and deliver next to the Seq
# extension in either import order, the refreshed one (InRepo) and the published 1.0.0 that ships its own older
# assemblies (Published); see docs/decisions/0012-otlp-sink-design.md.
$otlp = "$root/extensions/PoShLog.Sinks.OpenTelemetry/PoShLog.Sinks.OpenTelemetry.psd1"
$seqCase = $cases | Where-Object Name -eq 'PoShLog.Sinks.Seq'
$seqPaths = @()
if ($Mode -eq 'InRepo') {
    $cases += @{ Name = 'PoShLog.Sinks.OpenTelemetry'; Path = $otlp }
    $seqPaths += $seqCase.Path
    if ($LegacySeqPath) { $seqPaths += (Resolve-Path $LegacySeqPath).Path }
} elseif ($Mode -eq 'Published') {
    $seqPaths += $seqCase.Path
}
foreach ($seqPath in $seqPaths) {
    foreach ($first in $true, $false) {
        $cases += @{ Name = 'PoShLog.Sinks.OpenTelemetry'; Path = $otlp; Seq = $seqPath; SeqFirst = $first }
    }
}
$failed = @()
foreach ($case in $cases) {
    # One process per module: legacy assemblies must not mask failures in another extension.
    $startInfo = [Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh'))
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = @('-NoProfile', '-File', "$PSScriptRoot/Test-Extension.ps1", '-Name', $case.Name, '-ModulePath', $case.Path)
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
        Write-Output "FAIL $($case.Name) (45-second process timeout)"
        $failed += $case.Name
    } elseif ($process.ExitCode) {
        $failed += $case.Name
    }
    $output = $stdout.GetAwaiter().GetResult()
    $errors = $stderr.GetAwaiter().GetResult()
    Write-Output $output
    if ($errors) { Write-Output $errors }
    if ($env:GITHUB_ACTIONS -eq 'true' -and $failed -contains $case.Name) {
        # Annotations are readable through the public API; job logs need a signed-in user.
        $detail = (($output + "`n" + $errors) -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 15) -join '%0A'
        Write-Output "::error title=Compatibility $($case.Name) ($Mode)::$detail"
    }
    $process.Dispose()
}
if ($failed.Count) { throw "Compatibility failures: $($failed -join ', ')" }
Write-Output "PASS $Mode compatibility ($($cases.Count) cases)"
