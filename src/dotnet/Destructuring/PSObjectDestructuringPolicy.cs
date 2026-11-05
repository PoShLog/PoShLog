using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using Serilog.Core;
using Serilog.Debugging;
using Serilog.Events;

namespace PoShLog.Core.Destructuring
{
	/// <summary>
	/// Destructures PowerShell objects (<c>{@Value}</c>) the way PowerShell users see them, instead of letting
	/// Serilog reflect over the PSObject adapter (BaseObject, Members, TypeNames, ...), which recurses through
	/// PSMemberInfo values until the output explodes (issue #46).
	/// <list type="bullet">
	/// <item>A PSCustomObject becomes a structure of its PowerShell properties (note, alias, script, code properties).
	/// Methods and the adapter members are dropped; a property whose getter throws is skipped.</item>
	/// <item>A hashtable or other non-generic IDictionary (also when wrapped in a PSObject) becomes a dictionary keyed by
	/// its keys, not a sequence of DictionaryEntry structures.</item>
	/// <item>Any other PSObject is unwrapped and its base object is destructured as Serilog would destructure it.</item>
	/// <item>A PSObject or dictionary that is already being destructured further up the same value is written as
	/// <see cref="CircularReference"/>, so a cycle cannot recurse. Serilog's maximum destructuring depth still
	/// bounds everything else.</item>
	/// </list>
	/// See docs/decisions/0005-psobject-destructuring-policy.md.
	/// </summary>
	public sealed class PSObjectDestructuringPolicy : IDestructuringPolicy
	{
		public const string CircularReference = "[Circular]";

		[ThreadStatic]
		private static HashSet<object> _inProgress;

#if NETFRAMEWORK
		// Framework lacks the BCL reference comparer. Cycles must use object identity, including PSObject.
		private sealed class ReferenceEqualityComparer : IEqualityComparer<object>
		{
			internal static readonly ReferenceEqualityComparer Instance = new ReferenceEqualityComparer();
			public new bool Equals(object x, object y) => ReferenceEquals(x, y);
			public int GetHashCode(object obj) => System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(obj);
		}
#endif

		public bool TryDestructure(object value, ILogEventPropertyValueFactory propertyValueFactory, out LogEventPropertyValue result)
		{
			var target = value is PSObject wrapper && wrapper.BaseObject is IDictionary ? wrapper.BaseObject : value;
			if (target is not PSObject && target is not IDictionary)
			{
				result = null;
				return false;
			}

			var inProgress = _inProgress ??= new HashSet<object>(ReferenceEqualityComparer.Instance);
			if (!inProgress.Add(target))
			{
				result = new ScalarValue(CircularReference);
				return true;
			}

			try
			{
				result = target switch
				{
					IDictionary dictionary => DestructureDictionary(dictionary, propertyValueFactory),
					PSObject { BaseObject: PSCustomObject } custom => DestructureCustomObject(custom, propertyValueFactory),
					PSObject other => propertyValueFactory.CreatePropertyValue(other.BaseObject, destructureObjects: true),
					_ => throw new InvalidOperationException(),
				};
				return true;
			}
			finally
			{
				inProgress.Remove(target);
			}
		}

		private static DictionaryValue DestructureDictionary(IDictionary dictionary, ILogEventPropertyValueFactory propertyValueFactory)
		{
			var elements = new List<KeyValuePair<ScalarValue, LogEventPropertyValue>>();
			foreach (DictionaryEntry entry in dictionary)
			{
				var key = entry.Key is PSObject wrappedKey ? wrappedKey.BaseObject : entry.Key;
				elements.Add(new KeyValuePair<ScalarValue, LogEventPropertyValue>(
					new ScalarValue(key),
					propertyValueFactory.CreatePropertyValue(entry.Value, destructureObjects: true)));
			}

			return new DictionaryValue(elements);
		}

		private static StructureValue DestructureCustomObject(PSObject psObject, ILogEventPropertyValueFactory propertyValueFactory)
		{
			var properties = new List<LogEventProperty>();
			foreach (var property in psObject.Properties)
			{
				if (!property.IsGettable || !LogEventProperty.IsValidName(property.Name))
				{
					continue;
				}

				object propertyValue;
				try
				{
					propertyValue = property.Value;
				}
				catch (Exception ex)
				{
					SelfLog.WriteLine("PoShLog skipped property {0} while destructuring a PSCustomObject: {1}", property.Name, ex.Message);
					continue;
				}

				properties.Add(new LogEventProperty(property.Name, propertyValueFactory.CreatePropertyValue(propertyValue, destructureObjects: true)));
			}

			return new StructureValue(properties);
		}
	}
}
