using System.Management.Automation;
using PoShLog.Core.Enrichers.Extensions;

namespace PoShLog.Core.Data
{
	public class InvocationInfoWrapper
	{
		public CommandOrigin CommandOrigin { get; }
		public bool ExpectingInput { get; }
		public long HistoryId { get; }
		public string InvocationName { get; }
		public string MyCommand { get; }
		public int OffsetInLine { get; }
		public int PipelineLength { get; }
		public int PipelinePosition { get; }
		public string PSCommandPath { get; }
		public string PSScriptRoot { get; }
		public int ScriptLineNumber { get; }
		public string ScriptName { get; }

		public InvocationInfoWrapper(InvocationInfo invocationInfo)
		{
			CommandOrigin = invocationInfo.CommandOrigin;
			ExpectingInput = invocationInfo.ExpectingInput;
			HistoryId = invocationInfo.HistoryId;
			InvocationName = invocationInfo.InvocationName;
			MyCommand = invocationInfo.MyCommand?.Name;
			OffsetInLine = invocationInfo.OffsetInLine;
			PipelineLength = invocationInfo.PipelineLength;
			PipelinePosition = invocationInfo.PipelinePosition;
			PSCommandPath = invocationInfo.PSCommandPath;
			PSScriptRoot = invocationInfo.PSScriptRoot;
			ScriptLineNumber = invocationInfo.ScriptLineNumber;
			ScriptName = invocationInfo.ScriptName;
		}

		public override string ToString()
		{
			return this.ToTable();
		}
	}
}
