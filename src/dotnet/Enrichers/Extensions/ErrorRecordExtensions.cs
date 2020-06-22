using System.Linq;
using System.Management.Automation;
using System.Text;

namespace PoShLog.Core.Enrichers.Extensions
{
	public static class ErrorRecordExtensions
	{
		public static string ToTable(this ErrorRecord errorRecord)
		{
			var sb = new StringBuilder();

			sb.AppendLine("");
			sb.AppendLine($"{"CategoryInfo",-25} : {errorRecord.CategoryInfo,25}");
			sb.AppendLine($"{"FullyQualifiedErrorId",-25} : {errorRecord.FullyQualifiedErrorId,25}");
			sb.AppendLine($"{"ErrorDetails",-25} : {errorRecord.ErrorDetails,25}");
			sb.AppendLine($"{"InvocationInfo",-25} : {errorRecord.InvocationInfo,25}");
			sb.AppendLine($"{"ScriptStackTrace",-25} : {errorRecord.ScriptStackTrace,25}");
			sb.AppendLine($"{"PipelineIterationInfo",-25} : {errorRecord.PipelineIterationInfo,25}");

			return sb.ToString();
		}

		public static string ToTable(this InvocationInfo invocationInfo)
		{
			var sb = new StringBuilder();

			var boundParams = string.Join(", ", invocationInfo.BoundParameters.Select(kv => $"{kv.Key}:{kv.Value}"));
			sb.AppendLine("");
			sb.AppendLine($"{"BoundParameters",-25} : {boundParams,-25}");
			sb.AppendLine($"{"CommandOrigin",-25} : {invocationInfo.CommandOrigin,-25}");
			sb.AppendLine($"{"DisplayScriptPosition",-25} : {invocationInfo.DisplayScriptPosition,-25}");
			sb.AppendLine($"{"ExpectingInput",-25} : {invocationInfo.ExpectingInput,-25}");
			sb.AppendLine($"{"HistoryId",-25} : {invocationInfo.HistoryId,-25}");
			sb.AppendLine($"{"InvocationName",-25} : {invocationInfo.InvocationName,-25}");
			sb.AppendLine($"{"Line",-25} : {invocationInfo.Line,-25}");
			sb.AppendLine($"{"MyCommand",-25} : {invocationInfo.MyCommand,-25}");
			sb.AppendLine($"{"ScriptName",-25} : {invocationInfo.ScriptName,-25}");
			sb.AppendLine($"{"ScriptLineNumber",-25} : {invocationInfo.ScriptLineNumber,-25}");

			return sb.ToString();

		}
	}
}
