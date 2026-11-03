# PoShLog.Enrichers

[![psgallery](https://img.shields.io/powershellgallery/v/PoShLog.Enrichers.svg)](https://www.powershellgallery.com/packages/PoShLog.Enrichers) [![PowerShell Gallery](https://img.shields.io/powershellgallery/p/PoShLog.Enrichers?color=blue)](https://www.powershellgallery.com/packages/PoShLog.Enrichers) [![psgallery](https://img.shields.io/powershellgallery/dt/PoShLog.Enrichers.svg)](https://www.powershellgallery.com/packages/PoShLog.Enrichers) [![Discord](https://img.shields.io/discord/693754316305072199?color=orange&label=discord)](https://discord.gg/6USF98)

PoShLog.Enrichers is extension module for [PoShLog](https://github.com/PoShLog/PoShLog) logging module. Contains lot of helpful enricher methods, useful when enriching log messages with more properties.

Version 1.1.0 requires PoShLog 3.0.0 by GUID; PoShLog 2.x users stay on 1.0.x.

## Getting started

If you are familiar with PowerShell, skip to [Installation](#installation) section. For more detailed installation instructions check out [Getting started](../../docs/getting-started.md) guide.

### Installation

To install PoShLog.Enrichers, run following snippet from powershell:

```ps1
Install-Module -Name PoShLog.Enrichers
```

## Usage

```ps1
Import-Module PoShLog
Import-Module PoShLog.Enrichers

New-Logger |
    Add-EnrichWithEnvironment |
    Add-EnrichWithExceptionDetails |
    Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" |
    Start-Logger

Write-InfoLog 'Hurrray, my first log message!'

# Don't forget to close the logger
Close-Logger
```

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
