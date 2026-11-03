using System;
using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

public sealed class LegacySeqListener : IDisposable
{
    private readonly HttpListener listener = new HttpListener();
    private readonly Task worker;
    public readonly ConcurrentQueue<string> Bodies = new ConcurrentQueue<string>();
    public readonly ConcurrentQueue<string> Paths = new ConcurrentQueue<string>();
    public string Url { get; private set; }

    public LegacySeqListener()
    {
        for (int attempt = 0; ; attempt++)
        {
            var reservation = new TcpListener(IPAddress.Loopback, 0);
            reservation.Start();
            int port = ((IPEndPoint)reservation.LocalEndpoint).Port;
            reservation.Stop();
            if (port == 5240) continue;
            Url = "http://127.0.0.1:" + port + "/";
            listener.Prefixes.Clear();
            listener.Prefixes.Add(Url);
            try { listener.Start(); break; }
            catch (HttpListenerException) { if (attempt >= 9) throw; }
        }
        worker = Task.Run(async () =>
        {
            while (listener.IsListening)
            {
                try
                {
                    var context = await listener.GetContextAsync();
                    using (var reader = new StreamReader(context.Request.InputStream))
                        Bodies.Enqueue(await reader.ReadToEndAsync());
                    Paths.Enqueue(context.Request.RawUrl);
                    byte[] response = Encoding.UTF8.GetBytes("{}");
                    context.Response.ContentType = "application/json";
                    context.Response.ContentLength64 = response.Length;
                    await context.Response.OutputStream.WriteAsync(response, 0, response.Length);
                    context.Response.Close();
                }
                catch (Exception) { if (!listener.IsListening) break; }
            }
        });
    }

    public void Dispose()
    {
        listener.Stop();
        listener.Close();
        worker.GetAwaiter().GetResult();
    }
}
