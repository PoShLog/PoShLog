using System;
using System.Collections.Concurrent;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Threading.Tasks;

public sealed class CompatHttpListener : IDisposable
{
    private readonly HttpListener _listener = new HttpListener();
    private readonly Task _worker;
    public ConcurrentQueue<string> Bodies { get; } = new ConcurrentQueue<string>();
    public ConcurrentQueue<string> Paths { get; } = new ConcurrentQueue<string>();
    public string Url { get; }

    public CompatHttpListener()
    {
        // Reserve an ephemeral loopback port; retry if another process wins the handoff.
        for (var attempt = 0; ; attempt++)
        {
            var reservation = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
            reservation.Start();
            var port = ((IPEndPoint)reservation.LocalEndpoint).Port;
            reservation.Stop();
            if (port == 5240) continue;
            Url = $"http://127.0.0.1:{port}/";
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
                    var context = await _listener.GetContextAsync();
                    Stream input = context.Request.InputStream;
                    var encoding = context.Request.Headers["Content-Encoding"];
                    if (encoding == "gzip") input = new GZipStream(input, CompressionMode.Decompress);
                    else if (encoding == "deflate") input = new DeflateStream(input, CompressionMode.Decompress);
                    using var reader = new StreamReader(input);
                    Bodies.Enqueue(await reader.ReadToEndAsync());
                    Paths.Enqueue(context.Request.RawUrl);
                    var response = System.Text.Encoding.UTF8.GetBytes("{\"code\":0}");
                    context.Response.ContentType = "application/json";
                    context.Response.ContentLength64 = response.Length;
                    await context.Response.OutputStream.WriteAsync(response, 0, response.Length);
                    context.Response.Close();
                }
                catch (Exception) when (!_listener.IsListening) { break; }
            }
        });
    }

    public void Dispose()
    {
        _listener.Stop();
        _listener.Close();
        _worker.GetAwaiter().GetResult();
    }
}
