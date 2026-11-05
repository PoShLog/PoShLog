using System;
using System.Collections;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace PoShLog.Sinks.Http
{
    /// <summary>
    /// Transport owned and disposed by one sink. Implementations must observe cancellation,
    /// enforce finite request timeouts and transfer response ownership to the sink.
    /// The request stream is valid only until PostAsync completes.
    /// Configure runs once before delivery when a dictionary is supplied.
    /// </summary>
    public interface IHttpClient : IDisposable
    {
        void Configure(IDictionary configuration);
        Task<HttpResponseMessage> PostAsync(string requestUri, Stream content, CancellationToken cancellationToken);
    }
}
