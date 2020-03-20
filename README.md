# PoShLog [![psgallery](https://img.shields.io/powershellgallery/v/poshlog.svg)](https://www.powershellgallery.com/packages/PoShLog/) ![platform](https://img.shields.io/powershellgallery/p/poshlog.svg) [![psgallery](https://img.shields.io/powershellgallery/dt/poshlog.svg)](https://www.powershellgallery.com/packages/PoShLog/)

>Serilog for powershell

PoShLog is powershell logging module. It is wrapper of great C# logging library [Serilog](https://serilog.net/).
It allows you to log into console and file easily.

## Installation

Run from powershell

```ps1
Install-Module -Name PoShLog
```

## Usage

Minimum setup to log into console and file:

```ps1
Import-Module PoShLog

# Create and start new logger
Start-Logger -FilePath 'C:\Data\my_awesome.log'

Write-InfoLog 'Hurrray, my first log message!'

Close-Logger
```

Setup using pipeline fluent API:

```ps1
Import-Module PoShLog

# Create new logger
New-Logger |
    Add-SinkFile -Path 'C:\Data\my_awesome.log' |
    Add-SinkConsole |
    Start-Logger

# Test all log levels
Write-VerboseLog 'Test verbose message'
Write-DebugLog 'Test debug message'
Write-InfoLog 'Test info message'
Write-WarningLog 'Test warning message'
Write-ErrorLog -MessageTemplate 'Test Error message with properties {first}, {second}' -PropertyValues 'test1', 123

Close-Logger
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](https://github.com/TomasBouda/PoShLog/blob/master/LICENSE)