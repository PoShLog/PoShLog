# PoShLog [![psgallery](https://img.shields.io/powershellgallery/v/poshlog.svg)](https://www.powershellgallery.com/packages/PoShLog/) ![platform](https://img.shields.io/powershellgallery/p/poshlog.svg) [![psgallery](https://img.shields.io/powershellgallery/dt/poshlog.svg)](https://www.powershellgallery.com/packages/PoShLog/) [![Gitter](https://badges.gitter.im/TomLabsX/PoShLog.svg)](https://gitter.im/TomLabsX/PoShLog?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

>Serilog for powershell

PoShLog is powershell logging module. It is wrapper of great C# logging library [Serilog](https://serilog.net/).
PoShLog allows you to log structured event data into **console**, **file** and even more places easily.

## Getting started

If you are familiar with PowerShell, skip to [Installation](#installation) section. For more detailed installation instructions check out [Getting started](https://github.com/TomasBouda/PoShLog/wiki/Getting-started) wiki.

### Installation

To install PoShLog, run following snippet from powershel:

```ps1
Install-Module -Name PoShLog
```

## Usage

Minimum setup to log into console and file:

```ps1
Import-Module PoShLog

# Create and start new logger
Start-Logger -FilePath 'C:\Data\my_awesome.log' -Console

Write-InfoLog 'Hurrray, my first log message!'

# Don't forget to close the logger
Close-Logger
```

![poshlog_example_simplest_console](https://github.com/TomasBouda/PoShLog/blob/dev/images/poshlog_example_simplest_console.png?raw=true)

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

# Example of formatted output
$position = @{
    Latitude = 25
    Longitude = 134
}
$elapsedMs = 34

Write-InfoLog 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs

Close-Logger
```

### Documentation

These examples are just to get you started fast. For more detailed documentation please check [wiki](https://github.com/TomasBouda/PoShLog/wiki).

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## Authors

* [**Tomáš Bouda**](http://tomasbouda.cz/)

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/TomasBouda/PoShLog/blob/master/LICENSE) file for details.
