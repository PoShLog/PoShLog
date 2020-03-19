function New-Logger {

	try {
		# Just in case close and flush any previous logger
		Close-Logger
	}
	catch { }

	New-Object Serilog.LoggerConfiguration
}