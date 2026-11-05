// Copyright 2015-2026 Serilog Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Serilog.Debugging;
using Serilog.Events;
using Serilog.Formatting;
using Serilog.Formatting.Json;
using Serilog.Parsing;

// Modified for PoShLog: native namespace and dual-target build.
namespace PoShLog.Sinks.Http.TextFormatters;

/// <summary>
/// JSON formatter serializing log events into a normal format with its data normalized. The
/// lack of a rendered message means improved network load compared to
/// <see cref="NormalRenderedTextFormatter"/>. Often this formatter is complemented with a log
/// server that is capable of rendering the messages of the incoming log events.
/// </summary>
/// <seealso cref="NormalRenderedTextFormatter" />
/// <seealso cref="CompactTextFormatter" />
/// <seealso cref="CompactRenderedTextFormatter" />
/// <seealso cref="NamespacedTextFormatter" />
/// <seealso cref="ITextFormatter" />
public class NormalTextFormatter : ITextFormatter
{
    /// <summary>
    /// The delimiter used between fields.
    /// </summary>
    public const string DELIMITER = ",";

    /// <summary>
    /// The separator between keys and values.
    /// </summary>
    public const string SEPARATOR = ":";

    /// <summary>
    /// Gets or sets a value indicating whether the message is rendered into JSON.
    /// </summary>
    protected bool IsRenderingMessage { get; set; }

    /// <summary>
    /// Gets or sets the key describing the timestamp in JSON.
    /// </summary>
    protected string TimestampKey { get; set; } = "Timestamp";

    /// <summary>
    /// Gets or sets the key describing the level in JSON.
    /// </summary>
    protected string LevelKey { get; set; } = "Level";

    /// <summary>
    /// Gets or sets the key describing the message template in JSON.
    /// </summary>
    protected string MessageTemplateKey { get; set; } = "MessageTemplate";

    /// <summary>
    /// Gets or sets the key describing the rendered message in JSON.
    /// </summary>
    protected string RenderedMessageKey { get; set; } = "RenderedMessage";

    /// <summary>
    /// Gets or sets the key describing the exception in JSON.
    /// </summary>
    protected string ExceptionKey { get; set; } = "Exception";

    /// <summary>
    /// Gets or sets the key describing the trace id in JSON.
    /// </summary>
    protected string TraceIdKey { get; set; } = "TraceId";

    /// <summary>
    /// Gets or sets the key describing the span id in JSON.
    /// </summary>
    protected string SpanIdKey { get; set; } = "SpanId";

    /// <summary>
    /// Gets or sets the key describing the properties in JSON.
    /// </summary>
    protected string PropertiesKey { get; set; } = "Properties";

    /// <summary>
    /// Gets or sets the key describing the renderings in JSON.
    /// </summary>
    protected string RenderingsKey { get; set; } = "Renderings";

    /// <summary>
    /// Gets or sets the key describing a rendering format in JSON.
    /// </summary>
    protected string RenderingsFormatKey { get; set; } = "Format";

    /// <summary>
    /// Gets or sets the key describing a rendering in JSON.
    /// </summary>
    protected string RenderingsRenderingKey { get; set; } = "Rendering";

    /// <summary>
    /// Format the log event into the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    public void Format(LogEvent logEvent, TextWriter output)
    {
        try
        {
            var buffer = new StringWriter();
            FormatContent(logEvent, buffer);

            // If formatting was successful, write to output
            output.Write(buffer.ToString());
        }
        catch (Exception e)
        {
            LogNonFormattableEvent(logEvent, e);
        }
    }

    /// <summary>
    /// Writes the key and value to the output.
    /// </summary>
    /// <param name="key">The JSON key.</param>
    /// <param name="value">The JSON value.</param>
    /// <param name="output">The output.</param>
    /// <param name="delimStart">The preceding delimiter.</param>
    protected static void WriteProperty(string key, string value, TextWriter output, string delimStart = DELIMITER)
    {
        output.Write(delimStart);

        JsonValueFormatter.WriteQuotedJsonString(key, output);
        output.Write(SEPARATOR);
        JsonValueFormatter.WriteQuotedJsonString(value, output);
    }

    /// <summary>
    /// Gets the collection of tokens with formatting.
    /// </summary>
    /// <param name="logEvent">The log event.</param>
    /// <returns>The collection of found tokens.</returns>
    protected static IEnumerable<PropertyToken> GetTokensWithFormat(LogEvent logEvent) =>
        logEvent.MessageTemplate.Tokens
            .OfType<PropertyToken>()
            .Where(pt => pt.Format != null);

    /// <summary>
    /// Writes the timestamp in UTC format to the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteTimestamp(LogEvent logEvent, TextWriter output) =>
        WriteProperty(TimestampKey, logEvent.Timestamp.UtcDateTime.ToString("O"), output, string.Empty);

    /// <summary>
    /// Writes the log level to the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteLogLevel(LogEvent logEvent, TextWriter output) =>
        WriteProperty(LevelKey, logEvent.Level.ToString(), output);

    /// <summary>
    /// Writes the message template to the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteMessageTemplate(LogEvent logEvent, TextWriter output) =>
        WriteProperty(MessageTemplateKey, logEvent.MessageTemplate.Text, output);

    /// <summary>
    /// Writes the rendered message to the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteRenderedMessage(LogEvent logEvent, TextWriter output) =>
        WriteProperty(RenderedMessageKey, logEvent.MessageTemplate.Render(logEvent.Properties), output);

    /// <summary>
    /// Writes the exception to the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteException(LogEvent logEvent, TextWriter output) =>
        WriteProperty(ExceptionKey, logEvent.Exception?.ToString() ?? "", output);

    /// <summary>
    /// Writes the Trace ID to the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteTraceId(LogEvent logEvent, TextWriter output) =>
        WriteProperty(TraceIdKey, logEvent.TraceId?.ToString() ?? "", output);

    /// <summary>
    /// Writes the Span ID to the output.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteSpanId(LogEvent logEvent, TextWriter output) =>
        WriteProperty(SpanIdKey, logEvent.SpanId?.ToString() ?? "", output);

    /// <summary>
    /// Writes the properties key and the collection of properties to the output. Is internally
    /// calling <see cref="WritePropertiesValues"/> to write the collection.
    /// </summary>
    /// <param name="logEvent">The event to format.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteProperties(LogEvent logEvent, TextWriter output)
    {
        output.Write(DELIMITER);
        JsonValueFormatter.WriteQuotedJsonString(PropertiesKey, output);
        output.Write(SEPARATOR);
        output.Write("{");

        WritePropertiesValues(logEvent.Properties, output);

        output.Write('}');
    }

    /// <summary>
    /// Is called by <see cref="WriteProperties"/> to write the collection of properties to the
    /// output. Is internally calling <see cref="WritePropertyValue"/> to write the property.
    /// </summary>
    /// <param name="properties">The collection of log properties.</param>
    /// <param name="output">The output.</param>
    protected virtual void WritePropertiesValues(
        IReadOnlyDictionary<string, LogEventPropertyValue> properties,
        TextWriter output)
    {
        var precedingDelimiter = string.Empty;

        foreach (var property in properties)
        {
            output.Write(precedingDelimiter);
            precedingDelimiter = DELIMITER;

            WritePropertyValue(property.Key, property.Value, output);
        }
    }

    /// <summary>
    /// Is called by <see cref="WritePropertiesValues"/> to write the individual property and its
    /// value.
    /// </summary>
    /// <param name="key">The property name/key.</param>
    /// <param name="value">The property value.</param>
    /// <param name="output">The output.</param>
    protected virtual void WritePropertyValue(
        string key,
        LogEventPropertyValue value,
        TextWriter output)
    {
        JsonValueFormatter.WriteQuotedJsonString(key, output);
        output.Write(SEPARATOR);
        ValueFormatter.Instance.Format(value, output);
    }

    /// <summary>
    /// Writes the items with rendering formats to the output.
    /// </summary>
    /// <param name="tokensWithFormat">The collection of tokens that have formats.</param>
    /// <param name="properties">The collection of properties to fill the tokens.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteRenderings(
        IEnumerable<PropertyToken> tokensWithFormat,
        IReadOnlyDictionary<string, LogEventPropertyValue> properties,
        TextWriter output) =>
            WriteRenderings(tokensWithFormat.GroupBy(pt => pt.PropertyName), properties, output);

    /// <summary>
    /// Writes the items with rendering formats to the output.
    /// </summary>
    /// <param name="tokensGrouped">The collection of tokens that have formats, grouped by property name.</param>
    /// <param name="properties">The collection of properties to fill the tokens.</param>
    /// <param name="output">The output.</param>
    protected virtual void WriteRenderings(
        IEnumerable<IGrouping<string, PropertyToken>> tokensGrouped,
        IReadOnlyDictionary<string, LogEventPropertyValue> properties,
        TextWriter output)
    {
        output.Write(DELIMITER);
        JsonValueFormatter.WriteQuotedJsonString(RenderingsKey, output);
        output.Write(SEPARATOR);
        output.Write("{");

        var rdelim = string.Empty;
        foreach (var ptoken in tokensGrouped)
        {
            output.Write(rdelim);
            rdelim = DELIMITER;

            JsonValueFormatter.WriteQuotedJsonString(ptoken.Key, output);
            output.Write(SEPARATOR);
            output.Write("[");

            var fdelim = string.Empty;
            foreach (var format in ptoken)
            {
                output.Write(fdelim);
                fdelim = DELIMITER;

                var sw = new StringWriter();
                format.Render(properties, sw);

                output.Write("{");

                WriteProperty(RenderingsFormatKey, format.Format ?? "\"\"", output, delimStart: string.Empty);
                WriteProperty(RenderingsRenderingKey, sw.ToString(), output);

                output.Write('}');
            }

            output.Write(']');
        }

        output.Write('}');
    }

    private static void LogNonFormattableEvent(LogEvent logEvent, Exception e)
    {
        SelfLog.WriteLine(
            "Event at {0} with message template {1} could not be formatted into JSON and will be dropped: {2}",
            logEvent.Timestamp.ToString("o"),
            logEvent.MessageTemplate.Text,
            e);
    }

    private void FormatContent(LogEvent logEvent, TextWriter output)
    {
        if (logEvent == null) throw new ArgumentNullException(nameof(logEvent));
        if (output == null) throw new ArgumentNullException(nameof(output));

        output.Write("{");

        // Timestamp must be first as it does not have a preceding delimiter
        WriteTimestamp(logEvent, output);
        WriteLogLevel(logEvent, output);
        WriteMessageTemplate(logEvent, output);

        if (IsRenderingMessage)
        {
            WriteRenderedMessage(logEvent, output);
        }

        if (logEvent.Exception != null)
        {
            WriteException(logEvent, output);
        }

        if (logEvent.TraceId != null)
        {
            WriteTraceId(logEvent, output);
        }

        if (logEvent.SpanId != null)
        {
            WriteSpanId(logEvent, output);
        }

        if (logEvent.Properties.Count != 0)
        {
            WriteProperties(logEvent, output);
        }

        var tokensWithFormat = GetTokensWithFormat(logEvent);

        // ReSharper disable once PossibleMultipleEnumeration
        if (tokensWithFormat.Any())
        {
            // ReSharper disable once PossibleMultipleEnumeration
            WriteRenderings(tokensWithFormat, logEvent.Properties, output);
        }

        output.Write('}');
    }
}
