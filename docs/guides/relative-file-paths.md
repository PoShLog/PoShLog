# File paths and the PowerShell location

In v3, `Add-SinkFile -Path` and `Start-Logger -FilePath` resolve relative paths against
the current PowerShell location. They use PowerShell's FileSystem provider, including
custom PSDrives, and do not require the target file to exist. Native absolute paths
are preserved. Wildcards are literal; non-FileSystem providers are rejected.

```powershell
Set-Location $PSScriptRoot
New-Logger | Add-SinkFile -Path './logs/application.log' | Start-Logger
Write-InfoLog 'Started'
Close-Logger
```

This uses the location at configuration time, even if the process current directory
differs or you later change location. To explicitly use the caller's script directory,
pass `Join-Path $PSScriptRoot 'logs/application.log'`.
