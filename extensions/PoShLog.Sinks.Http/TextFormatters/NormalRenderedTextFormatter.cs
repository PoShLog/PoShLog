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

using Serilog.Formatting;

// Modified for PoShLog: native namespace and dual-target build.
namespace PoShLog.Sinks.Http.TextFormatters;

/// <summary>
/// JSON formatter serializing log events into a normal format with the message template
/// rendered into a message. This is the most verbose formatter and its network load is higher
/// than the other formatters.
/// </summary>
/// <seealso cref="NormalTextFormatter" />
/// <seealso cref="CompactTextFormatter" />
/// <seealso cref="CompactRenderedTextFormatter" />
/// <seealso cref="NamespacedTextFormatter" />
/// <seealso cref="ITextFormatter" />
public class NormalRenderedTextFormatter : NormalTextFormatter
{
    /// <summary>
    /// Initializes a new instance of the <see cref="NormalRenderedTextFormatter"/> class.
    /// </summary>
    public NormalRenderedTextFormatter()
    {
        IsRenderingMessage = true;
    }
}