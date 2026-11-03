using System.Management.Automation;
using PoShLog.Sinks.Http.HttpClients;

namespace PoShLog.Sinks.Http.CmdLets
{
	/// <summary>
	/// <para type="synopsis">Gets instance of <see cref="ApiKeyHttpClient"/></para>
	/// <para type="description">Gets instance of <see cref="ApiKeyHttpClient"/> that is then used by Add-SinkHttp cmdlet.</para>
	/// </summary>
	/// <example>
	/// <code>PS> New-Logger | Add-SinkHttp -RequestUri 'https://requestbin.net/r/6y06j5z8' -HttpClient (Get-ApiKeyHttpClient -ApiKey '...') | Start-Logger</code>
	/// </example>
	[Cmdlet(VerbsCommon.Get, "ApiKeyHttpClient")]
	[OutputType(typeof(ApiKeyHttpClient))]
	public class GetApiKeyHttpClient : PSCmdlet
	{
		/// <summary>
		/// <param type="description">Api key to be used in X-Api-key header</param>
		/// </summary>
		[Parameter(Mandatory = false)]
		public string ApiKey { get; set; }

		/// <inheritdoc />
		protected override void ProcessRecord()
		{
			WriteObject(new ApiKeyHttpClient(ApiKey));
		}
	}
}
