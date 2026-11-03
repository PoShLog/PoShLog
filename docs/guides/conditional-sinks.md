# Conditional sinks

`Add-SinkLogger -Filter` accepts a [Serilog expression](https://github.com/serilog/serilog-expressions#language-reference).
It routes matching events to an existing sublogger without filtering other sinks.

```powershell
$selected = New-Logger |
    Add-SinkFile -Path './selected.log' -OutputTemplate '{Message:lj}{NewLine}' |
    Start-Logger -PassThru
try {
    New-Logger |
        Add-SinkFile -Path './all.log' |
        Add-SinkLogger -Logger $selected -Filter 'Send = true' |
        Start-Logger
    Write-InfoLog 'Selected {Send}' -PropertyValues $true
    Write-InfoLog 'Local only {Send}' -PropertyValues $false
} finally {
    Close-Logger
    $selected.Dispose()
}
```

Replace the sublogger's File sink with `Add-SinkSeq` after importing its extension to
route only selected events to Seq. Both the parent and child minimum levels still
apply, as does `-RestrictedToMinimumLevel` on `Add-SinkLogger`. Configure the child
with `Set-MinimumLevel -Value Verbose` if it must accept Debug or Verbose events.

Use single quotes around expressions: `Environment = 'Production'` can be written
as `-Filter "Environment = 'Production'"`, and a level test as
`-Filter "@l = 'Error' or @l = 'Fatal'"`. Properties come from message arguments,
enrichers, or [LogContext](../cmdlets/Push-LogContextProperty.md). Missing properties
and results other than Boolean true do not match. Invalid expressions fail when
the sink is configured, before logging starts.

The expression is compiled once and can run on Serilog threads without a PowerShell
runspace. This parameter takes a string, not a PowerShell scriptblock; `$variables`,
`$_` and PowerShell operators such as `-eq` are not expression syntax.

The caller owns the child logger: closing the parent does not dispose it. Always
dispose it after the parent to flush buffered sinks. Without `-Filter`, existing
`Add-SinkLogger` behavior is unchanged. See [cmdlet reference](../cmdlets/Add-SinkLogger.md).
