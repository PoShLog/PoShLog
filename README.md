# PoShLog [![psgallery](https://img.shields.io/powershellgallery/v/poshlog.svg)](https://www.powershellgallery.com/packages/PoShLog/) ![platform](https://img.shields.io/powershellgallery/p/poshlog.svg) [![psgallery](https://img.shields.io/powershellgallery/dt/poshlog.svg)](https://www.powershellgallery.com/packages/PoShLog/)

>Serilog for powershell

PoShLog is powershell logging module. It is wrapper of great C# logging library [Serilog](https://serilog.net/).
It allows you to log structured event data into **console**, **file** and even more places easily.

## Getting started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

## Prerequisites

Altough PoShLog runs on TODO version of powershell I recommend you to install latest version.
You can do that simply by running(Assuming you have [.NET Core SDK](https://dotnet.microsoft.com/download) installed):

```ps1
dotnet tool install --global powershell
pwsh
```

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
Write-ErrorLog -MessageTemplate 'Test Error message with properties {first}, {second}' -PropertyValues 'test1', 123

Close-Logger
```

### Documentation

These examples are just the top of iceberg. For more detailed documentation please check [wiki](https://github.com/TomasBouda/PoShLog/wiki).

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## Authors

* [**Tomáš Bouda**](http://tomasbouda.cz/)

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/TomasBouda/PoShLog/blob/master/LICENSE) file for details