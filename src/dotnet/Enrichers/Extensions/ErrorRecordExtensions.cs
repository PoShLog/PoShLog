using System.Linq;
using PoShLog.Core.Data;
using PoShLog.Core.Utils;

namespace PoShLog.Core.Enrichers.Extensions
{
	public static class ErrorRecordExtensions
	{
		public static string ToTable(this ErrorRecordWrapper errorRecord)
		{
			var table = new Table();

			table.AddRow("CategoryInfo", errorRecord.CategoryInfo);
			table.AddRow("ErrorDetails", errorRecord.ErrorDetails);
			table.AddRow("FullyQualifiedErrorId", errorRecord.FullyQualifiedErrorId);
			table.AddRow("PipelineIterationInfo", errorRecord.PipelineIterationInfo);
			table.AddRow("ScriptStackTrace", errorRecord.ScriptStackTrace);
			table.AddRow("TargetObject", errorRecord.TargetObject);

			return table.ToString();
		}

		public static string ToTable(this InvocationInfoWrapper invocationInfo)
		{
			var table = new Table();

			var boundParams = string.Join(", ", invocationInfo.BoundParameters.Select(kv => $"{kv.Key}:{kv.Value}"));
			table.AddRow("BoundParameters", boundParams);
			table.AddRow("CommandOrigin", invocationInfo.CommandOrigin);
			table.AddRow("DisplayScriptPosition", invocationInfo.DisplayScriptPosition);
			table.AddRow("ExpectingInput", invocationInfo.ExpectingInput);
			table.AddRow("HistoryId", invocationInfo.HistoryId);
			table.AddRow("InvocationName", invocationInfo.InvocationName);
			table.AddRow("Line", invocationInfo.Line);
			table.AddRow("MyCommand", invocationInfo.MyCommand);
			table.AddRow("OffsetInLine", invocationInfo.OffsetInLine);
			table.AddRow("PipelineLength", invocationInfo.PipelineLength);
			table.AddRow("PipelinePosition", invocationInfo.PipelinePosition);
			table.AddRow("PSCommandPath", invocationInfo.PSCommandPath);
			table.AddRow("PSScriptRoot", invocationInfo.PSScriptRoot);
			table.AddRow("ScriptLineNumber", invocationInfo.ScriptLineNumber);
			table.AddRow("ScriptName", invocationInfo.ScriptName);
			table.AddRow("UnboundArguments", string.Join("; ", invocationInfo.UnboundArguments));

			return table.ToString();
		}
	}
}
