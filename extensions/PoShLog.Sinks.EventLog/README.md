# PoShLog.Sinks.EventLog

[![psgallery](https://img.shields.io/powershellgallery/v/poshlog.sinks.eventlog.svg)](https://www.powershellgallery.com/packages/PoShLog.Sinks.EventLog) [![PowerShell Gallery](https://img.shields.io/powershellgallery/p/poshlog.sinks.eventLog?color=blue)](https://www.powershellgallery.com/packages/PoShLog.Sinks.EventLog) [![psgallery](https://img.shields.io/powershellgallery/dt/PoShLog.Sinks.EventLog.svg)](https://www.powershellgallery.com/packages/PoShLog.Sinks.EventLog) [![Discord](https://img.shields.io/discord/693754316305072199?color=orange&label=discord)](https://discord.gg/FVdVxuw)

PoShLog.Sinks.EventLog is extension module for [PoShLog](https://github.com/PoShLog/PoShLog) logging module. Contains sink that publishes log messages to Windows Event Log.

Version 2.0.0 requires PoShLog 3.0.0 by GUID; PoShLog 2.x users stay on 1.0.x.

## Getting started

If you are familiar with PowerShell, skip to [Installation](#installation) section. For more detailed installation instructions check out [Getting started](../../docs/getting-started.md) guide.

### Installation

To install PoShLog.Sinks.EventLog, run following snippet from powershell:

```ps1
Install-Module PoShLog.Sinks.EventLog
```

## Usage

**Note that before first use you should run following as administrator to register your `-Source`(Sample Script). Notice the `-ManageEventSource` parameter.**

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.EventLog

New-Logger |
	Add-SinkEventLog -Source 'Sample Script' -ManageEventSource $true |
	Start-Logger

Close-Logger
```

After that you can run your scripts under default privileges and you can ommit `-ManageEventSource` parameter, as long as you don't change `-Source` parameter.

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.EventLog

New-Logger |
	Add-SinkEventLog -Source 'Sample Script' |
	Start-Logger

Write-InformationLog 'My message in windows event log'

Close-Logger
```

![image](https://user-images.githubusercontent.com/7009780/85843663-c4f17e80-b7a1-11ea-9207-0ce3eed031a3.png)

### Documentation

These examples are just to get you started fast. For more detailed documentation please check [docs](../../docs/cmdlets/README.md).

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## Authors

* [**Tomáš Bouda**](http://tomasbouda.cz/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

* Icon made by [Smashicons](https://smashicons.com/) from [www.flaticon.com](https://www.flaticon.com/).
