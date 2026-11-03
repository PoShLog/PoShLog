using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Text;

namespace PoShLog.Core.Cmdlets.Helpers
{
    /// <summary>Conservatively rewrites literal logging command calls for manual review.</summary>
    [Cmdlet(VerbsData.Convert, "LogFunctions", SupportsShouldProcess = true)]
    [OutputType(typeof(LogFunctionConversion))]
    public class ConvertLogFunctionsCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [Alias("FilePath", "FullName")]
        public string Path { get; set; }

        [Parameter]
        public SwitchParameter Force { get; set; }

        private sealed record Edit(int Offset, int Length, string Text);

        protected override void ProcessRecord()
        {
            try
            {
                ConvertFile(GetUnresolvedProviderPathFromPSPath(Path));
            }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException ||
                                       ex is ArgumentException || ex is NotSupportedException)
            {
                WriteError(new ErrorRecord(ex, "LogConversionFailed", ErrorCategory.WriteError, Path));
            }
        }

        private void ConvertFile(string path)
        {
            var original = File.ReadAllBytes(path);
            // Detect only encodings understood by ParseFile. Reject invalid input rather than replacing bytes.
            Encoding encoding;
            int bom;
            using (var reader = new StreamReader(new MemoryStream(original), new UTF8Encoding(false, true), true))
            {
                reader.Peek();
                encoding = (Encoding)reader.CurrentEncoding.Clone();
                encoding.DecoderFallback = DecoderFallback.ExceptionFallback;
                encoding.EncoderFallback = EncoderFallback.ExceptionFallback;
                var preamble = encoding.GetPreamble();
                bom = preamble.Length > 0 && original.AsSpan().StartsWith(preamble) ? preamble.Length : 0;
            }
            var text = encoding.GetString(original, bom, original.Length - bom);
            var ast = Parser.ParseFile(path, out _, out var errors);
            if (errors.Length != 0)
            {
                WriteError(new ErrorRecord(new ParseException(errors), "LogConversionParseError",
                    ErrorCategory.ParserError, path));
                return;
            }

            var edits = new List<Edit>();
            var findings = new List<LogFunctionConversion>();
            foreach (var command in ast.FindAll(a => a is CommandAst, true).Cast<CommandAst>())
            {
                var name = command.GetCommandName();
                var target = name?.ToLowerInvariant() switch
                {
                    "write-verbose" => "Write-VerboseLog",
                    "write-debug" => "Write-DebugLog",
                    "write-information" => "Write-InfoLog",
                    "write-host" => "Write-InfoLog",
                    "write-warning" => "Write-WarningLog",
                    "write-error" => "",
                    _ => null
                };
                if (target == null) continue;

                var local = new List<Edit>();
                var reason = target == "" ? "Write-Error must retain PowerShell error semantics." : null;
                if (reason == null) reason = PlanCommand(command, name, target, local);
                var before = command.Extent.Text;
                var after = reason == null ? Apply(before, local, command.Extent.StartOffset) : before;
                findings.Add(new LogFunctionConversion
                {
                    File = path, Line = command.Extent.StartLineNumber, Command = name,
                    Action = reason == null ? "Converted" : "Skipped", Before = before, After = after,
                    Reason = reason ?? "Command and parameter names converted; review before use."
                });
                if (reason == null) edits.AddRange(local);
            }

            if (edits.Count > 0)
            {
                if (ShouldProcess(path, "Back up original to " + path + ".bak and convert logging calls"))
                {
                    // Refuse stale offsets if the file changed while it was being inspected or confirmed.
                    if (!original.SequenceEqual(File.ReadAllBytes(path)))
                        throw new IOException("The file changed during conversion; no changes were written.");
                    var converted = Apply(text, edits, 0);
                    var body = encoding.GetBytes(converted);
                    var output = original.Take(bom).Concat(body).ToArray();
                    File.Copy(path, path + ".bak", Force.IsPresent);
                    var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
                    try
                    {
                        using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write))
                        {
                            stream.Write(output);
                            stream.Flush(true);
                        }
                        File.Move(temporary, path, true);
                    }
                    finally
                    {
                        if (File.Exists(temporary)) File.Delete(temporary);
                    }
                }
                else
                {
                    foreach (var finding in findings.Where(f => f.Action == "Converted"))
                    {
                        finding.Action = "Skipped";
                        finding.Reason = "ShouldProcess declined (WhatIf or confirmation); After shows the proposed change.";
                    }
                }
            }
            foreach (var finding in findings) WriteObject(finding);
        }

        private string PlanCommand(CommandAst command, string name, string target, List<Edit> edits)
        {
            for (var parent = command.Parent; parent != null; parent = parent.Parent)
                if (parent is ExpandableStringExpressionAst)
                    return "Commands inside strings require manual review.";
            if (command.InvocationOperator != TokenKind.Unknown)
                return "Invocation operators require manual review.";
            if (command.Parent is PipelineAst pipeline && pipeline.PipelineElements[0] != command)
                return "Pipeline input requires manual review.";
            if (command.Redirections.Count != 0) return "Stream redirection requires manual review.";
            if (command.FindAll(a => a is VariableExpressionAst v && v.Splatted, true).Any())
                return "Splatting cannot be checked statically.";

            var source = SessionState.InvokeCommand.GetCommand("Microsoft.PowerShell.Utility\\" + name, CommandTypes.Cmdlet);
            if (source == null) return "Built-in command metadata is unavailable.";
            var targetParameters = new CmdletInfo(target, typeof(Cmdlets.Write.WriteInfoLogCommand)).Parameters;
            var message = name.Equals("Write-Information", StringComparison.OrdinalIgnoreCase) ? "MessageData" :
                name.Equals("Write-Host", StringComparison.OrdinalIgnoreCase) ? "Object" : "Message";
            var positional = 0;
            var hasMessage = false;
            for (var i = 1; i < command.CommandElements.Count; i++)
            {
                var element = command.CommandElements[i];
                if (element is CommandParameterAst parameter)
                {
                    var candidates = source.Parameters.Values.Where(p =>
                        p.Name.Equals(parameter.ParameterName, StringComparison.OrdinalIgnoreCase) ||
                        p.Aliases.Any(a => a.Equals(parameter.ParameterName, StringComparison.OrdinalIgnoreCase))).ToArray();
                    if (candidates.Length == 0)
                        candidates = source.Parameters.Values.Where(p =>
                            p.Name.StartsWith(parameter.ParameterName, StringComparison.OrdinalIgnoreCase) ||
                            p.Aliases.Any(a => a.StartsWith(parameter.ParameterName, StringComparison.OrdinalIgnoreCase))).ToArray();
                    if (candidates.Length != 1) return "Unknown or ambiguous parameter: -" + parameter.ParameterName;
                    var resolved = candidates[0];
                    var isMessage = resolved.Name.Equals(message, StringComparison.OrdinalIgnoreCase);
                    if (!isMessage && !targetParameters.ContainsKey(resolved.Name))
                        return "Target cmdlet does not support parameter -" + resolved.Name + ".";
                    if (isMessage) hasMessage = true;
                    edits.Add(new Edit(parameter.Extent.StartOffset, 1 + parameter.ParameterName.Length,
                        "-" + (isMessage ? "MessageTemplate" : resolved.Name)));
                    if (resolved.ParameterType != typeof(SwitchParameter) && parameter.Argument == null)
                    {
                        if (++i >= command.CommandElements.Count || command.CommandElements[i] is CommandParameterAst)
                            return "Parameter value cannot be determined safely.";
                    }
                }
                else
                {
                    if (element.Extent.Text == "--%" || element.Extent.Text == "--")
                        return "Argument parsing markers require manual review.";
                    positional++;
                }
            }
            if (positional > (hasMessage ? 0 : 1)) return "Multiple message arguments require manual review.";
            if (!hasMessage && positional == 0) return "No explicit message was supplied.";
            edits.Add(new Edit(command.CommandElements[0].Extent.StartOffset,
                command.CommandElements[0].Extent.EndOffset - command.CommandElements[0].Extent.StartOffset, target));
            return null;
        }

        private static string Apply(string text, IEnumerable<Edit> edits, int origin)
        {
            var result = new StringBuilder(text);
            foreach (var edit in edits.OrderByDescending(e => e.Offset))
            {
                result.Remove(edit.Offset - origin, edit.Length);
                result.Insert(edit.Offset - origin, edit.Text);
            }
            return result.ToString();
        }
    }

    public sealed class LogFunctionConversion
    {
        public string File { get; set; }
        public int Line { get; set; }
        public string Command { get; set; }
        public string Action { get; set; }
        public string Before { get; set; }
        public string After { get; set; }
        public string Reason { get; set; }
    }
}
