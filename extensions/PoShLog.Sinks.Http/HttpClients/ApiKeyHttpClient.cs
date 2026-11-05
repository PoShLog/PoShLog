using System;
using System.Collections;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;

namespace PoShLog.Sinks.Http.HttpClients
{
    /// <summary>Reusable JSON transport with optional X-Api-Key authentication.</summary>
    public class ApiKeyHttpClient : IHttpClient
    {
        private readonly HttpClient _httpClient;

        public ApiKeyHttpClient() : this(null) { }

        public ApiKeyHttpClient(string apiKey)
        {
#if NET472
            // Inbox handler: retain OS TLS selection, proxy and certificate validation.
            _httpClient = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false });
#else
            _httpClient = new HttpClient(new SocketsHttpHandler
            {
                AllowAutoRedirect = false,
                PooledConnectionLifetime = TimeSpan.FromMinutes(2)
            });
#endif
            _httpClient.Timeout = TimeSpan.FromSeconds(30);
            SetApiKey(apiKey);
        }

        public void Configure(IDictionary configuration)
        {
            if (configuration != null && configuration.Contains("http:apiKey"))
                SetApiKey((string)configuration["http:apiKey"]);
        }

        private void SetApiKey(string apiKey)
        {
            _httpClient.DefaultRequestHeaders.Remove("X-Api-Key");
            if (!string.IsNullOrEmpty(apiKey)) _httpClient.DefaultRequestHeaders.Add("X-Api-Key", apiKey);
        }

        /// <summary>Convenience overload retained for callers supplying HttpContent.</summary>
        public Task<HttpResponseMessage> PostAsync(string requestUri, HttpContent content) =>
            _httpClient.PostAsync(requestUri, content);

        public async Task<HttpResponseMessage> PostAsync(string requestUri, Stream content, CancellationToken cancellationToken)
        {
            using var payload = new StreamContent(content);
            payload.Headers.ContentType = new MediaTypeHeaderValue("application/json");
            return await _httpClient.PostAsync(requestUri, payload, cancellationToken).ConfigureAwait(false);
        }

        public void Dispose() => _httpClient.Dispose();
    }
}
