# Enrichers

With enrichers, you can automatically add properties to log event messages — for example `MachineName`, `ProcessName`, or `ErrorRecord`. You can use an added property in a sink's `-OutputTemplate`, or view/process it later from a file or other storage location.

## Core enrichers

* [**Add-EnrichFromLogContext**](../cmdlets/Add-EnrichFromLogContext.md) - Adds properties pushed onto the ambient LogContext
* [**Add-EnrichWithErrorRecord**](../cmdlets/Add-EnrichWithErrorRecord.md) - Adds `ErrorRecord` property to log events
* [**Add-EnrichWithProperty**](../cmdlets/Add-EnrichWithProperty.md) - Adds custom properties to log events

## Extensions

*These enrichers require a separate extension module — see [Extension modules](extension-modules.md).*

* [**Add-EnrichWithEnvironment**](../enrichers/Add-EnrichWithEnvironment.md) - Adds `MachineName` and `EnvironmentUserName` properties to log events
* [**Add-EnrichWithExceptionDetails**](../enrichers/Add-EnrichWithExceptionDetails.md) - Adds additional structured properties from exceptions into log events
* [**Add-EnrichWithProcessId**](../enrichers/Add-EnrichWithProcessId.md) - Enriches log events with current `ProcessId` property
* [**Add-EnrichWithProcessName**](../enrichers/Add-EnrichWithProcessName.md) - Enriches log events with current `ProcessName` property
