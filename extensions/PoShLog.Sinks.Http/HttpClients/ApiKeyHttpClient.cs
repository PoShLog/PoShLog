using System.Net.Http;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Serilog.Sinks.Http;

namespace PoShLog.Sinks.Http.HttpClients
{
	/// <summary>
	/// HttpClient that authenticates each request using X-Api-key header
	/// </summary>
	public class ApiKeyHttpClient : IHttpClient
	{
		private readonly HttpClient _httpClient;

		/// <summary>
		/// Creates instance of <see cref="ApiKeyHttpClient"/>
		/// </summary>
		public ApiKeyHttpClient()
		{
			_httpClient = new HttpClient();
		}

		/// <summary>
		/// Creates instance of <see cref="ApiKeyHttpClient"/> with initial api key
		/// </summary>
		/// <param name="apiKey"></param>
		public ApiKeyHttpClient(string apiKey) : this()
		{
			_httpClient.DefaultRequestHeaders.Add("X-Api-Key", apiKey);
		}

		/// <summary>
		/// Configures the HTTP client.
		/// </summary>
		/// <param name="configuration">The application configuration properties.</param>
		public void Configure(IConfiguration configuration)
		{
			if (configuration != null)
			{
				var apiKey = configuration["http:apiKey"];

				_httpClient.DefaultRequestHeaders.Add("X-Api-Key", apiKey);
			}
		}

		/// <summary>
		///  Sends a POST request to the specified Uri as an asynchronous operation.
		/// </summary>
		/// <param name="requestUri">The Uri the request is sent to.</param>
		/// <param name="content">The HTTP request content sent to the server.</param>
		/// <returns>The task object representing the asynchronous operation.</returns>
		public Task<HttpResponseMessage> PostAsync(string requestUri, HttpContent content) => _httpClient.PostAsync(requestUri, content);

		public async Task<HttpResponseMessage> PostAsync(string requestUri, Stream content, CancellationToken cancellationToken)
        {
            using var payload = new StreamContent(content);
            payload.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/json");
            return await _httpClient.PostAsync(requestUri, payload, cancellationToken).ConfigureAwait(false);
        }

        public void Dispose() => _httpClient?.Dispose();
	}
}
