using System;
using System.Collections;
using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using PoShLog.Sinks.Http;
using Serilog.Events;
using Serilog.Formatting;

namespace PoShLog.Http.Tests
{
    public sealed class ReceivedRequest
    {
        public string Body { get; set; }
        public string ApiKey { get; set; }
        public string ContentType { get; set; }
        public string Method { get; set; }
    }

    public sealed class LoopbackEndpoint : IDisposable
    {
        private readonly HttpListener _listener = new HttpListener();
        private readonly Task _worker;
        public readonly ConcurrentQueue<ReceivedRequest> Requests = new ConcurrentQueue<ReceivedRequest>();
        public readonly ConcurrentQueue<Exception> Errors = new ConcurrentQueue<Exception>();
        public string Url { get; }
        public int FailuresRemaining;
        public int ResponseDelayMilliseconds;
        public int SuccessStatusCode = 200;
        public string RedirectLocation;

        public LoopbackEndpoint()
        {
            for (var attempt = 0; ; ++attempt)
            {
                var reservation = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
                reservation.Start();
                var port = ((IPEndPoint)reservation.LocalEndpoint).Port;
                reservation.Stop();
                if (port == 5240) continue;
                Url = "http://127.0.0.1:" + port + "/";
                _listener.Prefixes.Clear();
                _listener.Prefixes.Add(Url);
                try { _listener.Start(); break; }
                catch (HttpListenerException) when (attempt < 9) { }
            }
            _worker = Task.Run(async () =>
            {
                while (_listener.IsListening)
                {
                    try
                    {
                        var context = await _listener.GetContextAsync().ConfigureAwait(false);
                        using (var body = new MemoryStream())
                        {
                            await context.Request.InputStream.CopyToAsync(body).ConfigureAwait(false);
                            Requests.Enqueue(new ReceivedRequest
                            {
                                // Decode raw bytes without StreamReader silently stripping a UTF-8 BOM.
                                Body = Encoding.UTF8.GetString(body.ToArray()),
                                ApiKey = context.Request.Headers["X-Api-Key"],
                                ContentType = context.Request.ContentType,
                                Method = context.Request.HttpMethod
                            });
                        }
                        if (ResponseDelayMilliseconds > 0)
                            await Task.Delay(ResponseDelayMilliseconds).ConfigureAwait(false);
                        context.Response.StatusCode = Interlocked.Decrement(ref FailuresRemaining) >= 0 ? 503 : SuccessStatusCode;
                        if (RedirectLocation != null) context.Response.RedirectLocation = RedirectLocation;
                        context.Response.Close();
                    }
                    catch (Exception) when (!_listener.IsListening) { break; }
                    catch (HttpListenerException) { /* Expected after a client timeout. */ }
                    catch (Exception e) { Errors.Enqueue(e); }
                }
            });
        }

        public void Dispose()
        {
            _listener.Stop();
            _listener.Close();
            if (!_worker.Wait(TimeSpan.FromSeconds(5))) throw new TimeoutException("Loopback worker did not stop.");
            if (!Errors.IsEmpty) throw new AggregateException(Errors);
        }
    }

    public sealed class RecordingClient : IHttpClient
    {
        public readonly ConcurrentQueue<string> Attempts = new ConcurrentQueue<string>();
        public readonly ConcurrentQueue<string> Delivered = new ConcurrentQueue<string>();
        public readonly ManualResetEventSlim Started = new ManualResetEventSlim();
        public readonly TaskCompletionSource<bool> Release = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        public bool Block;
        public bool Throw;
        public int StatusCode = 200;
        public bool Disposed;
        public bool Configured;
        public bool CancellationPassed;
        public IDictionary Configuration;
        public int DisposeCount;

        public void Configure(IDictionary configuration)
        {
            Configured = true;
            Configuration = configuration;
            if (Throw) throw new InvalidOperationException("Synthetic configuration failure.");
        }

        public async Task<HttpResponseMessage> PostAsync(string requestUri, Stream content, CancellationToken cancellationToken)
        {
            CancellationPassed = cancellationToken.CanBeCanceled;
            using (var reader = new StreamReader(content, Encoding.UTF8, true, 1024, true))
                Attempts.Enqueue(await reader.ReadToEndAsync().ConfigureAwait(false));
            Started.Set();
            if (Block)
            {
                var canceled = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
                using (cancellationToken.Register(() => canceled.TrySetCanceled()))
                {
                    var completed = await Task.WhenAny(Release.Task, canceled.Task).ConfigureAwait(false);
                    await completed.ConfigureAwait(false);
                }
            }
            if (Throw) throw new HttpRequestException("Synthetic transport failure.");
            if (StatusCode >= 200 && StatusCode < 300) Delivered.Enqueue(Attempts.ToArray()[Attempts.Count - 1]);
            return new HttpResponseMessage((HttpStatusCode)StatusCode);
        }

        public void Dispose() { Disposed = true; Interlocked.Increment(ref DisposeCount); }
    }

    public sealed class MarkerFormatter : ITextFormatter
    {
        public void Format(LogEvent logEvent, TextWriter output) { output.Write("{\"custom\":true}"); }
    }

    public sealed class MarkerBatchFormatter : IBatchFormatter
    {
        public void Format(System.Collections.Generic.IEnumerable<string> events, TextWriter output)
        {
            output.Write("{\"customBatch\":[");
            output.Write(string.Join(",", events));
            output.Write("]}");
        }
    }
}
