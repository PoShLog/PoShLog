function Test-Logger{
	[Serilog.Log]::Logger.GetType() -eq [Serilog.Core.Logger]
}