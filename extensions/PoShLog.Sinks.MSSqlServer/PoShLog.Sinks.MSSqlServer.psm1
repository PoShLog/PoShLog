# Load only the thin entry assembly. Private packages must never be Add-Typed into PowerShell's context.
Import-Module (Join-Path $PSScriptRoot 'lib/PoShLog.Sinks.MSSqlServer.dll') -ErrorAction Stop
Export-ModuleMember -Cmdlet 'Add-SinkMSSqlServer'
