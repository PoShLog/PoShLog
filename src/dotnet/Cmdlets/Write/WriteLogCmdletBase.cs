using System;
using System.Management.Automation;
using PoShLog.Core.Exceptions;
using PoShLog.Core.Utils;
using Serilog;
using Serilog.Events;

namespace PoShLog.Core.Cmdlets.Write
{
	/// <summary>
	/// Common base for all Write-*Log cmdlets, mirroring the internal Write-Log.ps1 helper.
	/// </summary>
	public abstract class WriteLogCmdletBase : PSCmdlet
	{
		protected abstract LogEventLevel Level { get; }

		[Parameter(Mandatory = true, Position = 0, ValueFromPipeline = true, ParameterSetName = "MsgTemp")]
		[Parameter(Mandatory = false, Position = 0, ValueFromPipeline = true, ParameterSetName = "ErrRec")]
		[AllowEmptyString]
		public string MessageTemplate { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "MsgTemp")]
		[Parameter(Mandatory = false, ParameterSetName = "ErrRec")]
		public ILogger Logger { get; set; } = Log.Logger;

		[Parameter(Mandatory = false, ParameterSetName = "MsgTemp")]
		[Parameter(Mandatory = false, ParameterSetName = "ErrRec")]
		[AllowNull]
		public Exception Exception { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "ErrRec")]
		[Alias("ER")]
		[AllowNull]
		public ErrorRecord ErrorRecord { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "MsgTemp")]
		[Parameter(Mandatory = false, ParameterSetName = "ErrRec")]
		[AllowNull]
		public object[] PropertyValues { get; set; }

		[Parameter(Mandatory = false, ParameterSetName = "MsgTemp")]
		[Parameter(Mandatory = false, ParameterSetName = "ErrRec")]
		public SwitchParameter PassThru { get; set; }

		protected override void ProcessRecord()
		{
			PSCmdletContext.Current = this;
			try
			{
				var exception = Exception;

				if (ErrorRecord != null)
				{
					if (exception == null)
					{
						exception = ErrorRecord.Exception;
					}

					exception = new WrapperException(exception, ErrorRecord);
				}

				var messageTemplate = MessageTemplate ?? string.Empty;
				Logger.Write(Level, exception, messageTemplate, PropertyValues);

				if (PassThru.IsPresent)
				{
					var formatted = MessageFormatter.Format(Logger, Level, messageTemplate, PropertyValues, exception);
					if (formatted != null)
					{
						WriteObject(formatted);
					}
				}
			}
			finally
			{
				PSCmdletContext.Current = null;
			}
		}
	}
}
