function New-Logger{

	# Just in case close and flush any previous logger
	Close-Logger

	New-Object Serilog.LoggerConfiguration
}