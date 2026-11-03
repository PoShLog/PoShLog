@{

# Script module or binary module file associated with this manifest.
RootModule = 'PoShLog.Sinks.Syslog.Rfc5424.psm1'

# Version number of this module. A preview stays 0.x: release.yml accepts only plain versions.
ModuleVersion = '0.1.0'

# Supported PSEditions
CompatiblePSEditions = 'Core'

# ID used to uniquely identify this module
GUID = 'bfa9fc8f-3400-4b2e-99fe-0301445dfc34'

# Author of this module
Author = 'Tomas Bouda'

# Company or vendor of this module
CompanyName = 'Tomas Bouda'

# Copyright statement for this module
Copyright = '(c) 2026 Tomas Bouda. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PoShLog.Sinks.Syslog.Rfc5424 is extension module for PoShLog core library - https://www.powershellgallery.com/packages/PoShLog.
It contains sink that sends log messages to a syslog server over UDP, TCP or TLS, as RFC 5424 or RFC 3164 messages.

For documentation check PoShLog docs - https://github.com/PoShLog/PoShLog/tree/master/docs'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.4'

# Modules that must be imported into the global environment prior to importing this module (ADR 0004)
RequiredModules = @(@{ModuleName = 'PoShLog'; GUID = '6eabf344-4f00-4cc0-95d4-d3bef503e165'; ModuleVersion = '3.0.0'; })

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @()

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = 'Add-SinkSyslog'

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'syslog','rfc5424','rfc3164','rsyslog','syslog-ng','Log','Logging','Serilog','serilog-sink','serilog-for-powershell','wrapper','sinks','PSEdition_Core','Windows','Linux','MacOS'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PoShLog/PoShLog/blob/master/extensions/PoShLog.Sinks.Syslog.Rfc5424/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PoShLog/PoShLog/tree/master/extensions/PoShLog.Sinks.Syslog.Rfc5424'

        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/PoShLog/PoShLog/master/images/icons/poshlog-icon-sink-256.png'

        # ReleaseNotes of this module
        ReleaseNotes = 'https://github.com/PoShLog/PoShLog/blob/master/extensions/PoShLog.Sinks.Syslog.Rfc5424/CHANGELOG.md'

    } # End of PSData hashtable

 } # End of PrivateData hashtable

}
