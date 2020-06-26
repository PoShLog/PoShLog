using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;
using PoShLog.Core.Enrichers.Extensions;

namespace PoShLog.Core.Data
{
	public class InvocationInfoWrapper
	{
		public Dictionary<string, object> BoundParameters { get; }
		public CommandOrigin CommandOrigin { get; }
		public IScriptExtent DisplayScriptPosition { get; }
		public bool ExpectingInput { get; }
		public long HistoryId { get; }
		public string InvocationName { get; }
		public string Line { get; }
		public string MyCommand { get; }
		public int OffsetInLine { get; }
		public int PipelineLength { get; }
		public int PipelinePosition { get; }
		public string PositionMessage { get; }
		public string PSCommandPath { get; }
		public string PSScriptRoot { get; }
		public int ScriptLineNumber { get; }
		public string ScriptName { get; }
		public List<object> UnboundArguments { get; }

		public InvocationInfoWrapper(InvocationInfo invocationInfo)
		{
			BoundParameters = invocationInfo.BoundParameters;
			CommandOrigin = invocationInfo.CommandOrigin;
			DisplayScriptPosition = invocationInfo.DisplayScriptPosition;
			ExpectingInput = invocationInfo.ExpectingInput;
			HistoryId = invocationInfo.HistoryId;
			InvocationName = invocationInfo.InvocationName;
			Line = invocationInfo.Line;
			MyCommand = invocationInfo.MyCommand?.ToString();
			OffsetInLine = invocationInfo.OffsetInLine;
			PipelineLength = invocationInfo.PipelineLength;
			PipelinePosition = invocationInfo.PipelinePosition;
			PositionMessage = invocationInfo.PositionMessage;
			PSCommandPath = invocationInfo.PSCommandPath;
			PSScriptRoot = invocationInfo.PSScriptRoot;
			ScriptLineNumber = invocationInfo.ScriptLineNumber;
			ScriptName = invocationInfo.ScriptName;
			UnboundArguments = invocationInfo.UnboundArguments;
		}

		public override string ToString()
		{
			return this.ToTable();
		}
	}
}
