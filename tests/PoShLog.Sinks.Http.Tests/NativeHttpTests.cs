using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using PoShLog.Http.Tests;
using PoShLog.Sinks.Http;
using PoShLog.Sinks.Http.BatchFormatters;
using PoShLog.Sinks.Http.HttpClients;
using PoShLog.Sinks.Http.TextFormatters;
using Serilog;
using Serilog.Events;
using Serilog.Parsing;
using Xunit;

namespace PoShLog.Sinks.Http.Tests
{
    public class NativeHttpTests
    {
        private static LogEvent Event(bool rich)
        {
            var properties = rich ? new[]
            {
                new LogEventProperty("Number", new ScalarValue(12.5m)),
                new LogEventProperty("Text", new ScalarValue("quote \" slash \\ newline\n žluťoučký")),
                new LogEventProperty("Object", new StructureValue(new[] { new LogEventProperty("Value", new ScalarValue(true)) }, "Example")),
                new LogEventProperty("Array", new SequenceValue(new LogEventPropertyValue[] { new ScalarValue(null), new ScalarValue(double.NaN), new ScalarValue(3) })),
                new LogEventProperty("Map", new DictionaryValue(new[] { new KeyValuePair<ScalarValue, LogEventPropertyValue>(new ScalarValue("key"), new ScalarValue("value")) }))
            } : new LogEventProperty[0];
            var template = new MessageTemplateParser().Parse(rich ? "Hello {Text} {Number:0.00} {Number:000} {Missing:X}" : "Hello");
            return new LogEvent(new DateTimeOffset(2026, 11, 5, 12, 13, 14, TimeSpan.FromHours(2)),
                LogEventLevel.Warning, rich ? new InvalidOperationException("schema failure") : null, template, properties,
                rich ? ActivityTraceId.CreateFromString("0123456789abcdef0123456789abcdef".AsSpan()) : default,
                rich ? ActivitySpanId.CreateFromString("0123456789abcdef".AsSpan()) : default);
        }

        [Theory]
        [InlineData(false, "en-US")]
        [InlineData(true, "en-US")]
        [InlineData(true, "cs-CZ")]
        [InlineData(true, "ar-SA")]
        public void Default_schema_is_byte_identical_to_upstream_921(bool rich, string culture)
        {
            var old = CultureInfo.CurrentCulture;
            try
            {
                CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo(culture);
                var value = Event(rich);
                using var expected = new StringWriter();
                using var actual = new StringWriter();
                new Serilog.Sinks.Http.TextFormatters.NormalRenderedTextFormatter().Format(value, expected);
                new NormalRenderedTextFormatter().Format(value, actual);
                Assert.Equal(expected.ToString(), actual.ToString());
                using var expectedBatch = new StringWriter();
                using var actualBatch = new StringWriter();
                var items = new[] { expected.ToString(), "", " ", expected.ToString() };
                new Serilog.Sinks.Http.BatchFormatters.ArrayBatchFormatter().Format(items, expectedBatch);
                new ArrayBatchFormatter().Format(items, actualBatch);
                Assert.Equal(expectedBatch.ToString(), actualBatch.ToString());
            }
            finally { CultureInfo.CurrentCulture = old; }
        }

        [Fact]
        public void Array_empty_and_blank_inputs_match_upstream()
        {
            foreach (var values in new[] { new string[0], new[] { " ", null }, new[] { "{\"a\":1}", null, "{\"b\":2}" } })
            {
                using var expected = new StringWriter();
                using var actual = new StringWriter();
                new Serilog.Sinks.Http.BatchFormatters.ArrayBatchFormatter().Format(values, expected);
                new ArrayBatchFormatter().Format(values, actual);
                Assert.Equal(expected.ToString(), actual.ToString());
            }
        }

        [Fact]
        public void Legacy_envelope_limits_UTF8_event_bytes_and_can_disable_limit()
        {
            using var output = new StringWriter();
            new LegacyBatchFormatter(4).Format(new[] { "{}", "\"é\"", "\"éé\"", " " }, output);
            Assert.Equal("{\"events\":[{},\"é\"]}", output.ToString());
            using var unlimited = new StringWriter();
            new LegacyBatchFormatter(null).Format(new[] { new string('x', 262145) }, unlimited);
            Assert.Equal("{\"events\":[" + new string('x', 262145) + "]}", unlimited.ToString());
            using var defaults = new StringWriter();
            new LegacyBatchFormatter().Format(new[] { new string('x', 262144), new string('x', 262145) }, defaults);
            Assert.Equal("{\"events\":[" + new string('x', 262144) + "]}", defaults.ToString());
        }

        [Theory]
        [InlineData("")]
        [InlineData("relative")]
        [InlineData("file:///tmp/event")]
        [InlineData("ftp://localhost/")]
        public void Invalid_uri_fails_during_configuration(string uri)
        {
            Assert.Throws<ArgumentException>(() => new LoggerConfiguration().WriteTo.Http(uri));
        }

        [Theory]
        [InlineData(0, 1, 1)]
        [InlineData(-1, 1, 1)]
        [InlineData(1, 0, 1)]
        [InlineData(1, -1, 1)]
        [InlineData(1, 1, 0)]
        [InlineData(1, 1, -1)]
        public void Invalid_batch_queue_or_period_fails_during_configuration(int batch, int queue, int seconds)
        {
            Assert.Throws<ArgumentOutOfRangeException>(() => new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/", batch, queue, TimeSpan.FromSeconds(seconds)));
        }

        [Fact]
        public void Custom_contracts_get_configuration_cancellation_and_one_disposal()
        {
            var client = new RecordingClient();
            var dictionary = new Hashtable { ["test"] = 42 };
            using (var logger = new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/",
                formatter: new MarkerFormatter(), batchFormatter: new MarkerBatchFormatter(),
                httpClient: client, configuration: dictionary).CreateLogger())
                logger.Information("ignored");
            Assert.Same(dictionary, client.Configuration);
            Assert.True(client.Configured);
            Assert.True(client.CancellationPassed);
            Assert.Equal(1, client.DisposeCount);
            Assert.Equal("{\"customBatch\":[{\"custom\":true}]}", Assert.Single(client.Delivered));
        }

        [Fact]
        public void Failed_configuration_disposes_transferred_transport()
        {
            var client = new RecordingClient { Throw = true };
            Assert.Throws<InvalidOperationException>(() => new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/", httpClient: client, configuration: new Hashtable()));
            Assert.Equal(1, client.DisposeCount);
        }

        [Theory]
        [InlineData(false)]
        [InlineData(true)]
        public async Task Queue_saturation_drops_incoming_events_and_null_remains_unbounded(bool unbounded)
        {
            var client = new RecordingClient { Block = true };
            var logger = new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/",
                batchPostingLimit: 1, queueLimit: unbounded ? (int?)null : 2,
                period: TimeSpan.FromMilliseconds(10), httpClient: client).CreateLogger();
            try
            {
                logger.Information("first");
                Assert.True(client.Started.Wait(TimeSpan.FromSeconds(5)));
                for (var i = 0; i < 12; i++) logger.Information("queued {Index}", i);
            }
            finally { client.Release.TrySetResult(true); logger.Dispose(); }
            Assert.Equal(unbounded ? 13 : 3, client.Delivered.Count);
            Assert.Contains("first", client.Delivered.First());
            Assert.DoesNotContain(client.Delivered, b => b.Contains("\"Index\":11") && !unbounded);
            await Task.CompletedTask;
        }

        [Theory]
        [InlineData(301)]
        [InlineData(400)]
        [InlineData(429)]
        [InlineData(500)]
        [InlineData(503)]
        public void All_non_success_statuses_are_failures_and_shutdown_terminates(int status)
        {
            var client = new RecordingClient { StatusCode = status };
            var elapsed = Stopwatch.StartNew();
            using (var logger = new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/", httpClient: client).CreateLogger())
                logger.Information("failure");
            Assert.Empty(client.Delivered);
            Assert.NotEmpty(client.Attempts);
            Assert.True(client.Disposed);
            Assert.True(elapsed.Elapsed < TimeSpan.FromSeconds(5));
        }

        [Fact]
        public async Task Real_HTTP_failure_retries_then_recovers()
        {
            using var endpoint = new LoopbackEndpoint { FailuresRemaining = 1 };
            using (var logger = new LoggerConfiguration().WriteTo.Http(endpoint.Url, period: TimeSpan.FromMilliseconds(20)).CreateLogger())
            {
                logger.Information("recover-marker");
                var deadline = DateTime.UtcNow.AddSeconds(15);
                while (endpoint.Requests.Count < 2 && DateTime.UtcNow < deadline) await Task.Delay(20);
                Assert.True(endpoint.Requests.Count >= 2, "No retry was delivered.");
            }
            Assert.All(endpoint.Requests, request => Assert.Contains("recover-marker", request.Body));
        }

        [Theory]
        [InlineData(200)]
        [InlineData(204)]
        [InlineData(299)]
        public void Success_statuses_deliver_and_dispose(int status)
        {
            var client = new RecordingClient { StatusCode = status };
            using (var logger = new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/", httpClient: client).CreateLogger())
                logger.Information("success");
            Assert.Single(client.Delivered);
            Assert.True(client.Disposed);
        }

        [Fact]
        public void Close_flushes_all_remaining_events_and_honors_batch_limit()
        {
            var client = new RecordingClient();
            using (var logger = new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/",
                batchPostingLimit: 3, period: TimeSpan.FromHours(1), httpClient: client).CreateLogger())
                for (var i = 0; i < 20; ++i) logger.Information("flush {Index}", i);
            var payloads = client.Delivered.ToArray();
            for (var i = 0; i < 20; ++i) Assert.Single(payloads, p => p.Contains("\"Index\":" + i + "}"));
            Assert.All(payloads, p => Assert.InRange(p.Split(new[] { "\"Timestamp\"" }, StringSplitOptions.None).Length - 1, 1, 3));
        }

        [Fact]
        public async Task API_key_dictionary_replaces_constructor_value_on_real_HTTP()
        {
            using var endpoint = new LoopbackEndpoint();
            var client = new ApiKeyHttpClient("synthetic-initial");
            client.Configure(new Hashtable { ["http:apiKey"] = "synthetic-configured" });
            using (client)
            using (var body = new MemoryStream(System.Text.Encoding.UTF8.GetBytes("[]")))
            using (var response = await client.PostAsync(endpoint.Url, body, CancellationToken.None))
                Assert.True(response.IsSuccessStatusCode);
            var request = Assert.Single(endpoint.Requests);
            Assert.Equal("synthetic-configured", request.ApiKey);
            Assert.Equal("POST", request.Method);
            Assert.Equal("application/json", request.ContentType);
        }

        [Fact]
        public async Task Transport_returns_redirects_without_following_them()
        {
            using var target = new LoopbackEndpoint();
            using var redirect = new LoopbackEndpoint { SuccessStatusCode = 307, RedirectLocation = target.Url };
            using var client = new ApiKeyHttpClient("synthetic-redirect");
            using var stream = new MemoryStream(new byte[] { 91, 93 });
            using var response = await client.PostAsync(redirect.Url, stream, CancellationToken.None);
            Assert.Equal(307, (int)response.StatusCode);
            Assert.Empty(target.Requests);
        }

        [Fact]
        public async Task Transport_observes_caller_cancellation()
        {
            using var endpoint = new LoopbackEndpoint { ResponseDelayMilliseconds = 500 };
            using var client = new ApiKeyHttpClient();
            using var source = new CancellationTokenSource(100);
            using var stream = new MemoryStream(new byte[] { 91, 93 });
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() => client.PostAsync(endpoint.Url, stream, source.Token));
        }

        [Fact]
        public void Minimum_level_filters_before_admission()
        {
            var client = new RecordingClient();
            using (var logger = new LoggerConfiguration().WriteTo.Http("http://127.0.0.1/",
                restrictedToMinimumLevel: LogEventLevel.Error, httpClient: client).CreateLogger())
            {
                logger.Information("excluded");
                logger.Error("included");
            }
            Assert.DoesNotContain("excluded", string.Join("", client.Delivered));
            Assert.Contains("included", string.Join("", client.Delivered));
        }
    }
}
