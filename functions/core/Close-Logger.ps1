function Close-Logger{
	[Serilog.Log]::CloseAndFlush()
}