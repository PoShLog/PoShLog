[CmdletBinding()]
param(
    [ValidateSet('InRepo', 'Published')]
    [string]$Mode = 'InRepo',
    [string]$GalleryPath = (Join-Path $PSScriptRoot '../../.compat/gallery')
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$modules = [ordered]@{
    'PoShLog.Enrichers' = '1.0.0'
    'PoShLog.Sinks.Seq' = '1.0.0'
    'PoShLog.Sinks.EventLog' = '1.0.0'
    'PoShLog.Sinks.Http' = '1.0.1'
}
if ($Mode -eq 'Published') {
    if ($env:GITHUB_ACTIONS -ne 'true') {
        throw 'Published extensions may only be downloaded and executed in GitHub Actions.'
    }
    $modules['PoShLog.Sinks.Exceptionless'] = '1.0.0'
    $modules['PoShLog.Sinks.Syslog'] = '1.0.0'
    $modules['PoShLog.Sinks.DataDog'] = '0.1.1'
    $modules['PoShLog.Sinks.ElmahIo'] = '4.0.4'
    $modules['PoShLog.Sinks.Splunk'] = '1.0.4'
    New-Item -ItemType Directory -Force $GalleryPath | Out-Null
}
$cases = @(@{ Name = 'PoShLog'; Path = "$root/src/PoShLog.psd1" })
foreach ($name in $modules.Keys) {
    if ($name -eq 'PoShLog.Sinks.EventLog' -and !$IsWindows) {
        Write-Output "SKIP $name (Windows only)"
        continue
    }
    if ($Mode -eq 'Published') {
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
$failed = @()
foreach ($case in $cases) {
    # One process per module: legacy assemblies must not mask failures in another extension.
    $startInfo = [Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh'))
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @('-NoProfile', '-File', "$PSScriptRoot/Test-Extension.ps1", '-Name', $case.Name, '-ModulePath', $case.Path)) {
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
    Write-Output $stdout.GetAwaiter().GetResult()
    $errors = $stderr.GetAwaiter().GetResult()
    if ($errors) { Write-Output $errors }
    $process.Dispose()
}
if ($failed.Count) { throw "Compatibility failures: $($failed -join ', ')" }
Write-Output "PASS $Mode compatibility ($($cases.Count) modules)"
