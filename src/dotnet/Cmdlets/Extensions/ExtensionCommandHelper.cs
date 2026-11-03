using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Language;
using PoShLog.Core.Catalog;

namespace PoShLog.Core.Cmdlets.Extensions
{
	internal static class ExtensionCommandHelper
	{
		internal const string PSResourceGet = "Microsoft.PowerShell.PSResourceGet";

		/// <summary>
		/// Runs a command in the caller's runspace, so that commands, functions and mocks it can see are used, and passes
		/// its warnings and verbose messages on. Errors are returned for the caller to decide.
		/// </summary>
		internal static Collection<PSObject> Run(PSCmdlet cmdlet, string command, IDictionary parameters, out IReadOnlyList<ErrorRecord> errors)
		{
			using var shell = PowerShell.Create(RunspaceMode.CurrentRunspace);
			shell.AddCommand(command).AddParameters(parameters);
			var output = shell.Invoke();
			foreach (var warning in shell.Streams.Warning)
			{
				cmdlet.WriteWarning(warning.Message);
			}
			foreach (var verbose in shell.Streams.Verbose)
			{
				cmdlet.WriteVerbose(verbose.Message);
			}
			errors = shell.Streams.Error.ToList();
			return output;
		}

		internal static void RequireCommand(PSCmdlet cmdlet, string command)
		{
			if (cmdlet.InvokeCommand.GetCommand(command, CommandTypes.Cmdlet | CommandTypes.Function | CommandTypes.Alias) == null)
			{
				cmdlet.ThrowTerminatingError(new ErrorRecord(
					new InvalidOperationException($"{command} was not found. It comes with the {PSResourceGet} module, which ships with PowerShell 7.4 and newer; install it with 'Install-Module {PSResourceGet}'."),
					"PSResourceGetMissing", ErrorCategory.ObjectNotFound, command));
			}
		}

		/// <summary>The version of a module or resource as "1.2.3" or "1.2.3-preview2".</summary>
		internal static string FormatVersion(object version, string prerelease) =>
			string.IsNullOrEmpty(prerelease) ? version?.ToString() : $"{version}-{prerelease}";

		internal static string GetPrerelease(PSModuleInfo module) =>
			((module.PrivateData as Hashtable)?["PSData"] as Hashtable)?["Prerelease"]?.ToString();

		internal static ErrorRecord UnknownExtension(string name) => new ErrorRecord(
			new ItemNotFoundException($"'{name}' is not a first-party PoShLog extension. Known extensions: {string.Join(", ", ExtensionCatalog.Extensions.Select(e => e.Name))}."),
			"UnknownExtension", ErrorCategory.ObjectNotFound, name);
	}

	/// <summary>Completes -Name with the extensions in the catalogue.</summary>
	public class ExtensionNameCompleter : IArgumentCompleter
	{
		public IEnumerable<CompletionResult> CompleteArgument(string commandName, string parameterName, string wordToComplete, CommandAst commandAst, IDictionary fakeBoundParameters)
		{
			var pattern = WildcardPattern.Get((wordToComplete ?? string.Empty).Trim('\'', '"') + "*", WildcardOptions.IgnoreCase);
			return ExtensionCatalog.Extensions
				.Where(e => pattern.IsMatch(e.Name))
				.Select(e => new CompletionResult(e.Name, e.Name, CompletionResultType.ParameterValue, e.Summary.Length > 0 ? e.Summary : e.Name));
		}
	}
}
