#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CoreManifest,
    [string]$ModuleManifest,
    [ValidateSet('CoreFirst', 'OtherFirst')][string]$Order,
    [string]$Results = (Join-Path $PSScriptRoot '../../.compat/desktop-coexistence')
)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Third-party module coexistence runs in GitHub Actions only.' }
if ($ModuleManifest) {
    if ($PSEdition -ne 'Desktop') { throw 'The coexistence child must run in powershell.exe.' }
    $env:PSModulePath = Join-Path $PSHOME 'Modules'
    if ($Order -eq 'CoreFirst') { Import-Module $CoreManifest -ErrorAction Stop }
    Import-Module $ModuleManifest -ErrorAction Stop
    if ($Order -eq 'OtherFirst') { Import-Module $CoreManifest -ErrorAction Stop }
    $file = Join-Path $Results "$([IO.Path]::GetFileNameWithoutExtension($ModuleManifest))-$Order.json"
    New-Logger | Add-SinkFile -Path $file -Formatter (Get-CompactFormatter) | Start-Logger
    Write-InfoLog 'coexistence marker'
    Close-Logger
    if ((Get-Content $file -Raw) -notmatch 'coexistence marker') { throw 'Coexistence file delivery failed.' }
    Write-Output "PASS Desktop coexistence $ModuleManifest $Order"
    exit 0
}
New-Item $Results -ItemType Directory -Force | Out-Null
$CoreManifest = (Resolve-Path $CoreManifest).Path
# These pinned releases declare a Windows PowerShell 5.1-compatible minimum host.
foreach ($module in @(
    @{ Name = 'Az.Accounts'; Version = '2.19.0' },
    @{ Name = 'PnP.PowerShell'; Version = '1.12.0' },
    @{ Name = 'PSFramework'; Version = '1.12.346' }
)) {
    $directory = Join-Path $Results "$($module.Name)/$($module.Version)"
    $package = Join-Path $Results "$($module.Name).$($module.Version).nupkg"
    Invoke-WebRequest "https://www.powershellgallery.com/api/v2/package/$($module.Name)/$($module.Version)" -OutFile $package
    [IO.Compression.ZipFile]::ExtractToDirectory($package, $directory, $true)
    $manifest = Join-Path $directory "$($module.Name).psd1"
    foreach ($importOrder in 'CoreFirst', 'OtherFirst') {
        # A separate process keeps each module's shared System.* assemblies out of the next case.
        $process = Start-Process (Get-Command powershell.exe).Source -WindowStyle Hidden -PassThru -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', "`"$PSCommandPath`"", '-CoreManifest', "`"$CoreManifest`"",
            '-ModuleManifest', "`"$manifest`"", '-Order', $importOrder, '-Results', "`"$Results`""
        ) -RedirectStandardOutput "$Results/$($module.Name)-$importOrder.out.log" -RedirectStandardError "$Results/$($module.Name)-$importOrder.err.log"
        if (!$process.WaitForExit(90000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "Coexistence timed out for $($module.Name) $importOrder."
        }
        Get-Content "$Results/$($module.Name)-$importOrder.out.log"
        Get-Content "$Results/$($module.Name)-$importOrder.err.log"
        if ($process.ExitCode) { throw "Coexistence failed for $($module.Name) $importOrder." }
        $process.Dispose()
    }
}
