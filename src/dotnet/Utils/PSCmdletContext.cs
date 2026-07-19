using System;
using System.Management.Automation;

namespace PoShLog.Core.Utils
{
	/// <summary>
	/// Tracks the currently executing cmdlet on the calling thread so that sinks/callbacks that
	/// are invoked synchronously deep inside Serilog (e.g. the PowerShell sink) can write to the
	/// correct pipeline streams (Verbose/Debug/Warning/Information) of the cmdlet that triggered
	/// the log call, mirroring how the original script-based implementation relied on PowerShell's
	/// ambient pipeline context when calling Write-Verbose/Write-Warning/etc.
	/// </summary>
	public static class PSCmdletContext
	{
		[ThreadStatic]
		private static Cmdlet _current;

		public static Cmdlet Current
		{
			get => _current;
			set => _current = value;
		}
	}
}
