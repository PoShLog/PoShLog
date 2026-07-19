# Log event levels

List of all event levels, taken from the [Serilog documentation](https://github.com/serilog/serilog/wiki/Configuration-Basics#minimum-level).

| Level | Usage |
|-|-|
| Verbose | Verbose is the noisiest level, rarely (if ever) enabled for a production app. |
| Debug | Debug is used for internal system events that are not necessarily observable from the outside, but useful when determining how something happened. |
| Information | Information events describe things happening in the system that correspond to its responsibilities and functions. Generally these are the observable actions the system can perform. |
| Warning | When a service is degraded, endangered, or may be behaving outside of its expected parameters, Warning level events are used. |
| Error | When functionality is unavailable or expectations broken, an Error event is used. |
| Fatal | The most critical level, Fatal events demand immediate attention. |
