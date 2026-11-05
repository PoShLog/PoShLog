# Keep these checks independent of the machine so their boundaries can be tested.
function Assert-PoShLogCoreHost {
    param([version] $Version)

    if ($Version -lt [version]'7.6') {
        throw "PoShLog requires PowerShell 7.6 or later on Core. Current version: $Version."
    }
}

function Assert-PoShLogDesktopFramework {
    param([long] $Release)

    if ($Release -lt 461808) {
        throw "PoShLog requires .NET Framework 4.7.2 or later on Windows PowerShell (Release >= 461808). Current Release: $Release."
    }
}

if ($PSEdition -eq 'Desktop') {
    # Do not throw in a pipeline here. The failure must terminate module import.
    foreach ($module in (Get-Module -Name PoShLog -All)) {
        if ($module.Version.Major -eq 2) {
            throw 'PoShLog 3 cannot load while PoShLog 2.x is loaded. Start a clean PowerShell session.'
        }
    }

    $binaryFolder = Join-Path $PSScriptRoot 'lib/net472'
    # Read metadata only. Loading Serilog here would defeat the import-order guard.
    $serilogVersion = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $binaryFolder 'Serilog.dll')).Version
    foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
        $identity = $assembly.GetName()
        if ($identity.Name -eq 'Serilog' -and $identity.Version -lt $serilogVersion) {
            throw "PoShLog requires Serilog $serilogVersion, but Serilog $($identity.Version) is already loaded. Start a clean PowerShell session."
        }
    }

    $framework = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue
    Assert-PoShLogDesktopFramework -Release $framework.Release
} elseif ($PSEdition -eq 'Core') {
    Assert-PoShLogCoreHost -Version $PSVersionTable.PSVersion
    $binaryFolder = Join-Path $PSScriptRoot 'lib/net10.0'
} else {
    throw "PoShLog does not support PowerShell edition '$PSEdition'."
}

$binaryPath = Join-Path $binaryFolder 'PoShLog.Core.dll'
if ($PSEdition -eq 'Desktop') {
    # TODO ADR 0031: register the compiled Desktop resolver here, after all guards
    # and BEFORE Import-Module enumerates Core's cmdlet types. The future bootstrap
    # must load Core and call its registration entry point without first resolving
    # Core-owned dependencies. No resolver entry point exists in Core yet.
}

# A local nested import gives the script module ownership of the binary exports.
$coreModule = Import-Module -Name $binaryPath -PassThru -Scope Local -ErrorAction Stop
# Rebind aliases to this script module. A forwarded binary alias otherwise keeps
# PoShLog.Core as its ModuleName on Desktop and is absent from Get-Command -Module PoShLog.
foreach ($alias in $coreModule.ExportedAliases.Values) {
    Remove-Item -LiteralPath ("Alias:\" + $alias.Name) -Force
    Set-Alias -Name $alias.Name -Value $alias.Definition -Description $alias.Description -Option $alias.Options -Scope Local -Force
}
Export-ModuleMember -Function @() -Variable @() -Cmdlet @($coreModule.ExportedCmdlets.Keys) -Alias @($coreModule.ExportedAliases.Keys)
