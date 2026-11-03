@{

# Script module or binary module file associated with this manifest.
RootModule = 'PoShLog.Sinks.OpenTelemetry.psm1'

# Version number of this module. A preview stays 0.x: release.yml accepts only plain versions.
ModuleVersion = '0.1.0'

# Supported PSEditions
CompatiblePSEditions = 'Core'

# ID used to uniquely identify this module
GUID = '97129603-4274-495f-8f64-a5e9f44e2a6f'

# Author of this module
Author = 'Tomas Bouda'

# Company or vendor of this module
CompanyName = 'Tomas Bouda'

# Copyright statement for this module
Copyright = '(c) 2026 Tomas Bouda. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PoShLog.Sinks.OpenTelemetry is extension module for PoShLog core library - https://www.powershellgallery.com/packages/PoShLog.
It contains sink that sends log messages over OTLP (HTTP/protobuf or gRPC) to an OpenTelemetry Collector or any backend with an OTLP intake: Seq, Grafana, .NET Aspire, Datadog, Splunk, Elastic.

For documentation check PoShLog docs - https://github.com/PoShLog/PoShLog/tree/master/docs'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.4'

# Modules that must be imported into the global environment prior to importing this module (ADR 0004)
RequiredModules = @(@{ModuleName = 'PoShLog'; GUID = '6eabf344-4f00-4cc0-95d4-d3bef503e165'; ModuleVersion = '3.0.0'; })

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @()

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = 'Add-SinkOpenTelemetry'

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'opentelemetry','otel','otlp','grpc','Log','Logging','Serilog','serilog-sink','serilog-for-powershell','wrapper','sinks','seq','grafana','aspire','datadog','splunk','elastic','PSEdition_Core','Windows','Linux','MacOS'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PoShLog/PoShLog/blob/master/extensions/PoShLog.Sinks.OpenTelemetry/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PoShLog/PoShLog/tree/master/extensions/PoShLog.Sinks.OpenTelemetry'

        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/PoShLog/PoShLog/master/images/icons/poshlog-icon-sink-256.png'

        # ReleaseNotes of this module
        ReleaseNotes = 'https://github.com/PoShLog/PoShLog/blob/master/extensions/PoShLog.Sinks.OpenTelemetry/CHANGELOG.md'

    } # End of PSData hashtable

 } # End of PrivateData hashtable

}
