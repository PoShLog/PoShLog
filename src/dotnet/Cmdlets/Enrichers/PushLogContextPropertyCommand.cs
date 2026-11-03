using System;
using System.Collections;
using System.Linq;
using System.Management.Automation;
using Serilog.Context;
using Serilog.Core;
using Serilog.Core.Enrichers;

namespace PoShLog.Core.Cmdlets.Enrichers
{
	/// <summary>
	/// Pushes properties onto the Serilog LogContext. Every event logged while they are on the context carries them,
	/// provided the logger enriches from it (Add-EnrichFromLogContext).
	/// With -ScriptBlock the properties apply while the block runs and are popped afterwards, even when it throws.
	/// Without it the cmdlet returns the bookmark; call Dispose() on it, ideally in a finally block, to pop them.
	/// See docs/decisions/0006-push-logcontextproperty-scope.md.
	/// </summary>
	[Cmdlet(VerbsCommon.Push, "LogContextProperty", DefaultParameterSetName = "Single")]
	[OutputType(typeof(IDisposable))]
	public class PushLogContextPropertyCommand : PSCmdlet
	{
		[Parameter(Mandatory = true, Position = 0, ParameterSetName = "Single")]
		[ValidateNotNullOrEmpty]
		public string Name { get; set; }

		[Parameter(Mandatory = true, Position = 1, ParameterSetName = "Single")]
		[AllowNull]
		public object Value { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "Multiple")]
		[ValidateNotNull]
		public IDictionary Property { get; set; }

		[Parameter(Mandatory = false)]
		public SwitchParameter Destructure { get; set; }

		[Parameter(Mandatory = false, Position = 2)]
		public ScriptBlock ScriptBlock { get; set; }

		protected override void EndProcessing()
		{
			var enrichers = ParameterSetName == "Multiple"
				? Property.Keys.Cast<object>().Select(key => CreateEnricher(Convert.ToString(key), Property[key])).ToArray()
				: new[] { CreateEnricher(Name, Value) };

			var bookmark = LogContext.Push(enrichers);

			if (ScriptBlock == null)
			{
				WriteObject(bookmark);
				return;
			}

			try
			{
				foreach (var output in InvokeCommand.InvokeScript(true, ScriptBlock, null))
				{
					WriteObject(output);
				}
			}
			finally
			{
				bookmark.Dispose();
			}
		}

		private ILogEventEnricher CreateEnricher(string name, object value)
		{
			if (string.IsNullOrEmpty(name))
			{
				throw new PSArgumentException("Every LogContext property needs a non-empty name.", nameof(Property));
			}

			// A wrapped scalar (an int from the pipeline) is logged as the scalar, not as its ToString(); a
			// PSCustomObject stays a PSObject so the destructuring policy can read its properties.
			if (value is PSObject psObject && psObject.BaseObject is not PSCustomObject)
			{
				value = psObject.BaseObject;
			}

			return new PropertyEnricher(name, value, Destructure.IsPresent);
		}
	}
}
